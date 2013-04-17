require 'date'
require File.join(File.dirname(__FILE__), "lib", "knife-ilo.rb")

Gem::Specification.new do |s|
  s.name        = 'knife-ilo'
  s.version     = KnifeIlo::VERSION
  s.date        = Date.today.to_s
  s.summary     = "Knife ilo plugin"
  s.description = "Manage your iLo from chef"
  s.authors     = ["Nicolas Szalay"]
  s.email       = 'nico@rottenbytes.info'
  s.files       = %w[
                    README.md
                    lib/knife-ilo.rb
                    lib/chef/knife/ilo-firmwares.rb
                    lib/chef/knife/ilo-update.rb
                    lib/chef/knife/ilo-reset.rb
                    lib/chef/knife/ilo-setup.rb
                  ]
  s.homepage    = 'http://www.rottenbytes.info'
end
