require 'chef/knife'

module KnifeIlo
  class IloFirmwares < Chef::Knife

    banner "knife ilo firmwares"

    option :debug,
      :short => '-d',
      :long  => '--debug',
      :description => "turn debug on",
      :default => false

    deps do
      require 'chef/data_bag'
      require 'chef/data_bag_item'
      require 'chef/json_compat'
      require 'chef/knife/search'
      require 'chef/environment'
      require 'chef/cookbook/metadata'
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
      list_firmwares()
    end

    def list_firmwares
      versions = Dir.open(@@cfg["global"]["ilo_firmware_path"]).entries
      versions.delete(".")
      versions.delete("..")
      versions.each do |v|
        if v =~ /v\d/ then # looks like a good candidate !
          files = Dir.open(@@cfg["global"]["ilo_firmware_path"]+ "/" + v).entries
          files.delete(".")
          files.delete("..")
          puts "Firmwares in #{v}"
          files.each do |f|
            puts " * #{f}"
          end
        end
      end
    end

  end
end
