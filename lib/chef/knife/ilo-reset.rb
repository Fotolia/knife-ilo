require 'chef/knife'

module KnifeIlo
  class IloReset < Chef::Knife

    banner "knife ilo reset NODE"

    deps do
      require 'chef/json_compat'
      require 'chef/knife/search'
      require 'chef/knife/core/object_loader'
    end

    @@cfg_files = [ "/etc/ilo-config.yml", "~/.chef/ilo-config.yml" ]

    def load_config
      loaded = false
      @@cfg_files.each do |cfg_file|
        begin
          @@cfg=YAML::load_file(File.expand_path(cfg_file))
          loaded = true
        rescue Exception => e
          puts "Error on loading config : #{e.inspect}" if config[:debug]
        end
      end
      unless loaded == true
        ui.error "config could not be loaded ! Tried the following files : #{@@cfg_files.join(", ")}"
        exit 1
      end
      puts @@cfg.inspect if config[:debug]
    end

    def run
      load_config()
      reset_ilo()
    end

    def reset_ilo()
      if name_args.count < 1 then
        ui.error "Usage : knife ilo reset NODE"
        exit 1
      end

      node = name_args.first
      q = Chef::Search::Query.new
      escaped_query = URI.escape("fqdn:#{node}", Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))

      rslt = q.search('node', escaped_query)

      if rslt[0].count > 1 then
        ui.error "Found more than one node for #{node} ! Giving up"
        exit 1
      end

      if rslt[0].count <1 then
        ui.error "#{node} not found ! Stopping here"
        exit 1
      end

      begin
        ip = rslt[0][0]["bootstrap"]["ilo"]["ip"]
        username = rslt[0][0]["bootstrap"]["ilo"]["username"]
        password = rslt[0][0]["bootstrap"]["ilo"]["password"]
      rescue
        ui.error "Incorrectly formatted attributes for #{node}. Please check documentation (or report bug)"
        exit 1
      end

      answer = ui.ask_question("About to reset #{node}'s iLo. is that OK ? (Y/N) ", :default => "N").upcase

      unless answer == "Y"
        ui.error "Aborting"
        exit 1
      end

      # everything seems OK, let's generate our XML file
      require "tempfile"
      xml_file = Tempfile.new("/tmp")
      xml_file.write('<RIBCL VERSION="2.0">')
      xml_file.write('  <LOGIN USER_LOGIN="' + username + '" PASSWORD="' + password + '">')
      xml_file.write('    <RIB_INFO MODE="write">')
      xml_file.write('      <RESET_RIB/>')
      xml_file.write('    </RIB_INFO>')
      xml_file.write('  </LOGIN>')
      xml_file.write('</RIBCL>')
      xml_file.close

      # call locfg.pl
      puts "calling locfg"
      result = %x[#{@@cfg["global"]["locfg_path"]} -s #{ip} -f #{xml_file.path}]

      xml_file.delete
    end
  end
end
