require 'chef/knife'

module KnifeIlo
  class IloUpdate < Chef::Knife

    banner "knife ilo update <NODE> <VERSION>"

    option :debug,
      :short => '-d',
      :long  => '--debug',
      :description => "turn debug on",
      :default => false

    option :ilo,
      :short => "-i VERSION",
      :long => "--ilo VERSION",
      :description => "change ilo version (2 or 3)",
      :default => "3"

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
      update_ilo()
    end

    def update_ilo()
      if name_args.count < 2 then
        ui.error "Usage : knife ilo update NODE FIRMWARE [--debug] [--ilo]"
        exit 1
      end

      node = name_args.first
      firmware = name_args[1]

      unless check_firmware(firmware, config[:ilo])
        ui.error "Firmware file #{@@cfg["global"]["ilo_firmware_path"]}/v#{config[:ilo]}/#{firmware} not found !"
        exit 1
      end

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

      answer = ui.ask_question("About to update #{node} (ilo v#{config[:ilo]}) with the following firmware file. OK ? (Y/N) ", :default => "N").upcase

      unless answer == "Y"
          ui.error "Aborting"
          exit 1
      end

      # everything seems OK, let's generate our XML file
      require "tempfile"
      xml_file = Tempfile.new("/tmp")
      xml_file.write('<RIBCL VERSION="2.0">' + "\n")
      xml_file.write('<LOGIN USER_LOGIN="' + username + '" PASSWORD="' + password + '">' + "\n")
      xml_file.write('  <RIB_INFO MODE="write">' + "\n")
      xml_file.write('    <TPM_ENABLED VALUE="Yes"/>' + "\n")
      xml_file.write('    <UPDATE_RIB_FIRMWARE IMAGE_LOCATION="' + expand_firmware_path(firmware, config[:ilo]) + '"/>' + "\n")
      xml_file.write('  </RIB_INFO>' + "\n")
      xml_file.write('</LOGIN>' + "\n")
      xml_file.write('</RIBCL>' + "\n")
      xml_file.close

      # call locfg.pl
      puts "calling locfg"
      #puts "#{@@cfg["global"]["locfg_path"]} -s #{ip} -f #{xml_file.path}"
      result = %x[#{@@cfg["global"]["locfg_path"]} -s #{ip} -f #{xml_file.path}]
      xml_file.delete
    end

    private

    def check_firmware(firmware_file, ilo_version)
      if File.exists?(@@cfg["global"]["ilo_firmware_path"] + "/v" + ilo_version + "/" + firmware_file)
        return true
      end
      return false
    end

    def expand_firmware_path(firmware_file, ilo_version)
      return File.join(@@cfg["global"]["ilo_firmware_path"], "v#{ilo_version}", firmware_file)
    end

  end
end

