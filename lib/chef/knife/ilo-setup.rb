require 'chef/knife'

module KnifeIlo
  class IloSetup < Chef::Knife

    banner "knife ilo setup NODE"

    option :yes,
      :short => "-y",
      :long => "--yes",
      :description => "Say yes to all",
      :default => false,
      :boolean => true

    option :ipaddress,
      :short => "-a IP",
      :long => "--address IP",
      :description => "IP address to run script against",
      :default => nil

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
      setup_ilo()
    end

    def setup_ilo()
      if name_args.count < 1 then
        ui.error "Usage : knife ilo setup NODE"
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
        site = rslt[0][0]["bootstrap"]["physical_location"]["datacenter"]
        hostname = rslt[0][0]["bootstrap"]["hostname"]
      rescue
        ui.error "Incorrectly formatted attributes for #{node}. Please check documentation (or report bug)"
        exit 1
      end

      if config[:yes] == true
        answer = "Y"
      end

      unless config[:yes] == true
        answer = ui.ask_question("About to set networking for #{node}'s iLo. is that OK ? (Y/N) ", :default => "N").upcase
      end

      unless answer == "Y"
        ui.error "Aborting"
        exit 1
      end

      # everything seems OK, let's generate our XML file
      require "tempfile"
      xml_file = Tempfile.new("/tmp")
      xml_file.write("<RIBCL VERSION=\"2.0\">\n")
      xml_file.write("<LOGIN USER_LOGIN=\"#{username}\" PASSWORD=\"#{password}\">\n")
      xml_file.write("  <RIB_INFO MODE=\"write\">\n")
      xml_file.write("    <MOD_NETWORK_SETTINGS>\n")
      xml_file.write("      <DHCP_ENABLE value=\"No\"/>\n")
      xml_file.write("      <IP_ADDRESS value=\"#{ip}\"/>\n")
      xml_file.write("      <SUBNET_MASK value=\"255.255.254.0\"/>\n")
      xml_file.write("      <GATEWAY_IP_ADDRESS value=\"#{@@cfg["sites"][site]["gateway"]}\"/>\n")
      xml_file.write("      <DNS_NAME value=\"#{hostname.split('.')[0]}\"/>\n")
      xml_file.write("      <DOMAIN_NAME value=\"#{site}.#{@@cfg["sites"]["all"]["domain_name"]}\"/>\n")
      xml_file.write("      <PRIM_DNS_SERVER value=\"#{@@cfg["sites"]["all"]["dns_servers"][0]}\"/>\n")
      xml_file.write("      <SEC_DNS_SERVER value=\"#{@@cfg["sites"]["all"]["dns_servers"][1]}\"/>\n")
      xml_file.write("    </MOD_NETWORK_SETTINGS>\n")
      xml_file.write("  </RIB_INFO>\n")
      xml_file.write("</LOGIN>\n")
      xml_file.write("</RIBCL>\n")
      xml_file.close

      if config[:ipaddress]
        net_ip = config[:ipaddress]
      else
        net_ip = ip
      end

      result = %x[#{@@cfg["global"]["locfg_path"]} -s #{net_ip} -f #{xml_file.path}]
      xml_file.delete
    end
  end
end
