FIXNUM_MAX = (2**(0.size * 8 - 2) - 1)

Rake::Task['db:create'].enhance do
  if ENV['RAILS_ENV']
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
  else
    ActiveRecord::Base.establish_connection(:development)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.establish_connection(:development)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')

    ActiveRecord::Base.establish_connection(:test)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.establish_connection(:test)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
  end
end

namespace :data_cycle_core do
  namespace :clear do
    desc "Remove all data except for configuration data like users"
    task :all => :environment do
      DataCycleCore::Classification.destroy_all
      DataCycleCore::ClassificationAlias.destroy_all
      DataCycleCore::CreativeWork.destroy_all
      DataCycleCore::Event.destroy_all
      DataCycleCore::Person.destroy_all
      DataCycleCore::Place.destroy_all
    end

    desc "Remove all contents related data like creative works and places (does not remove classifications)"
    task :contents => :environment do
      DataCycleCore::CreativeWork.where(template: false).destroy_all
      DataCycleCore::Event.where(template: false).destroy_all
      DataCycleCore::Person.where(template: false).destroy_all
      DataCycleCore::Place.where(template: false).destroy_all
    end
  end

  namespace :import do
    desc "List available endpoints for import"
    task :list => :environment do
      DataCycleCore::ExternalSource.all.each do |external_source|
        puts "#{external_source.id} - #{external_source.name}"
      end
    end

    desc "Download and import data from given data source"
    task :perform, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = Hash[{max_count: FIXNUM_MAX}.merge(args.to_h).map { |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      }]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.download(options)
      external_source.import(options)
    end

    desc "Only download data from given data source"
    task :download, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = Hash[{max_count: nil}.merge(args.to_h).map { |k, v|
        if k == :max_count && v
          [k, v.to_i]
        else
          [k, v]
        end
      }]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.download(options) do |on|
        on.preparing_phase { |label|
          puts "Preparing #{label.to_s.gsub(/_/, ' ')} ..."
        }
        on.phase_started { |label, total|
          puts "Downloading #{label.to_s.gsub(/_/, ' ')} ..." if total.nil?
          puts "Downloading #{label.to_s.gsub(/_/, ' ')} (#{total} items) ..." if total
        }
        on.item_processed { |title, id, num, total|
          puts " -> \"#{title} (\##{id})\" downloaded (#{num} of #{total || '?'})"
        }
        on.error { |title, id, data, error|
          puts "Error downloading \"#{title} (\##{id})\": #{error}"
          puts "  DATA: #{JSON.pretty_generate(data).gsub(/\n/, "\n  ")}"
        }
        on.phase_finished { |label, total|
          puts "Downloading #{label.to_s.gsub(/_/, ' ')} (#{total} items) ... [DONE]"
        }
      end
    end

    desc "Only import (without downloading) data from given data source"
    task :import, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = Hash[{max_count: FIXNUM_MAX}.merge(args.to_h).map { |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      }]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.import(options)
    end
  end
end
