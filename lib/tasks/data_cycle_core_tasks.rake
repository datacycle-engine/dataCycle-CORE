FIXNUM_MAX = (2**(0.size * 8 - 2) - 1)

delete_classifications = <<-eos
  DELETE FROM classifications;
  DELETE FROM classification_groups;
  DELETE FROM classification_aliases;
  DELETE FROM classification_trees;
  DELETE FROM classification_tree_labels;
eos

delete_secondary_data = <<-eos
  DELETE FROM watch_list_data_hashes;
  DELETE FROM watch_lists;
  DELETE FROM subscriptions;
  DELETE FROM data_links;
eos

delete_contents = <<-eos
  DELETE FROM creative_works;
  DELETE FROM creative_work_translations;
  DELETE FROM events;
  DELETE FROM event_translations;
  DELETE FROM persons;
  DELETE FROM person_translations;
  DELETE FROM places;
  DELETE FROM place_translations;

  DELETE FROM creative_work_events;
  DELETE FROM creative_work_persons;
  DELETE FROM creative_work_places;
  DELETE FROM event_persons;
  DELETE FROM event_places;
  DELETE FROM person_places;

  DELETE FROM classification_contents;
  DELETE FROM searches;

  DELETE FROM overlays;
  DELETE FROM tags;
  DELETE FROM overlay_place_tags;
eos

delete_content_histories = <<-eos
  DELETE FROM creative_work_histories;
  DELETE FROM creative_work_history_translations;
  DELETE FROM event_histories;
  DELETE FROM event_history_translations;
  DELETE FROM person_histories;
  DELETE FROM person_history_translations;
  DELETE FROM place_histories;
  DELETE FROM place_history_translations;

  DELETE FROM creative_work_event_histories;
  DELETE FROM creative_work_person_histories;
  DELETE FROM creative_work_place_histories;
  DELETE FROM event_person_histories;
  DELETE FROM event_place_histories;
  DELETE FROM person_place_histories;

  DELETE FROM classification_content_histories;
eos


Rake::Task['db:create'].enhance do
  if ENV['RAILS_ENV']
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "pg_trgm";')
  else
    ActiveRecord::Base.establish_connection(:development)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.establish_connection(:development)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
    ActiveRecord::Base.establish_connection(:development)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "pg_trgm";')

    ActiveRecord::Base.establish_connection(:test)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.establish_connection(:test)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
    ActiveRecord::Base.establish_connection(:test)
                      .connection.execute('CREATE EXTENSION IF NOT EXISTS "pg_trgm";')
  end
end

namespace :data_cycle_core do
  namespace :clear do
    desc "Remove all data except for configuration data like users"
    task :all => :environment do
      ActiveRecord::Base.connection.exec_query(delete_classifications)
      ActiveRecord::Base.connection.exec_query(delete_secondary_data)
      ActiveRecord::Base.connection.exec_query(delete_contents)
      ActiveRecord::Base.connection.exec_query(delete_content_histories)
    end

    desc "Remove all contents related data like creative works and places (does not remove classifications)"
    task :contents => :environment do
      ActiveRecord::Base.connection.exec_query(delete_secondary_data)
      ActiveRecord::Base.connection.exec_query(delete_contents)
      ActiveRecord::Base.connection.exec_query(delete_content_histories)
    end

    desc "Remove the history of all content data"
    task :history => :environment do
      ActiveRecord::Base.connection.exec_query(delete_content_histories)
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

      # TODO: remove --- to test multilingual support
      options[:locales] = [:de, :en, :fr, :it, :nl]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.download(options) do |on|
        on.preparing_phase { |label|
          puts "Preparing  #{label.to_s.gsub(/_/, ' ')} ..."
        }
        on.phase_started { |label, total|
          puts "Download   #{label.to_s.gsub(/_/, ' ')} ..." if total.nil?
          puts "Download   #{label.to_s.gsub(/_/, ' ')} (#{total} items) ..." if total
        }
        on.item_processed { |title, id, num, total|
          puts " -> \"#{title} (\##{id})\" downloaded (#{num} of #{total || '?'})"
        }
        on.error { |title, id, data, error|
          if title && id
            puts "Error downloading \"#{title} (\##{id})\": #{error}"
          elsif title
            puts "Error downloading \"#{title}\": #{error}"
          elsif id
            puts "Error downloading \"\##{id}\": #{error}"
          else
            puts "Error: #{error}"
          end
          puts "  DATA: #{JSON.pretty_generate(data).gsub(/\n/, "\n  ")}" if data
        }
        on.phase_finished { |label, total|
          puts "Downloaded #{label.to_s.gsub(/_/, ' ')} (#{total} items) ... [DONE]"
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
      external_source.import(options) do |on|
        on.preparing_phase { |label|
          puts "Preparing #{label.to_s.gsub(/_/, ' ')} ..."
        }
        on.phase_started { |label, total|
          puts "Importing #{label.to_s.gsub(/_/, ' ')} ..." if total.nil?
          puts "Importing #{label.to_s.gsub(/_/, ' ')} (#{total} items) ..." if total
        }
        on.item_processed { |title, id, num, total|
          # puts " -> \"#{title} (\##{id})\" imported (#{num} of #{total || '?'})"
        }
        on.error { |title, id, data, error|
          if title && id
            puts "Error importing \"#{title} (\##{id})\": #{error}"
          elsif title
            puts "Error importing \"#{title}\": #{error}"
          elsif id
            puts "Error importing \"\##{id}\": #{error}"
          else
            puts "Error: #{error}"
          end
          puts "  DATA: #{JSON.pretty_generate(data).gsub(/\n/, "\n  ")}" if data
        }
        on.phase_finished { |label, total|
          puts "Importing #{label.to_s.gsub(/_/, ' ')} (#{total} items) ... [DONE]"
        }
      end
    end


    desc "DEBUG: Only download data from given data source"
    task :download_new, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = Hash[{max_count: nil}.merge(args.to_h).map { |k, v|
        if k == :max_count && v
          [k, v.to_i]
        else
          [k, v]
        end
      }]

      options[:locales] = [:de, :en, :fr, :it, :nl]
      options[:logging_strategy] = DataCycleCore::Generic::Logger::Console.new("download")
      options[:source_type] = DataCycleCore::Generic::SourceType::ImageObject
      options[:endpoint] = DataCycleCore::Generic::DownloadStrategy::EndpointMediaArchive
      options[:download_strategy] = DataCycleCore::Generic::DownloadStrategy::MediaArchive

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.download(options)
    end

    desc "DEBUG: Only import (without downloading) data from given data source"
    task :import_new, [:external_source_id, :max_count] => [:environment] do |t, args|
      options = Hash[{max_count: FIXNUM_MAX}.merge(args.to_h).map { |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      }]

      options[:locales] = [:de, :fr, :en, :it, :nl]
      options[:data_template] = 'BildJsonld'
      options[:logging_strategy] = DataCycleCore::Generic::Logger::Console.new("import")
      options[:import_strategy] = DataCycleCore::Generic::ImportStrategy::MediaArchive
      options[:source_type] = DataCycleCore::Generic::SourceType::ImageObject
      options[:target_type] = DataCycleCore::CreativeWork

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.import(options)
    end


  end

  namespace :update do
    desc "import template definitions"
    task :import_templates => [:environment] do
      path = Rails.root.join('config','data_definitions','creative_works','*.yml')
      DataCycleCore::MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::CreativeWork)
      path = Rails.root.join('config','data_definitions','places','*.yml')
      DataCycleCore::MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Place)
      path = Rails.root.join('config','data_definitions','persons','*.yml')
      DataCycleCore::MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Person)
      path = Rails.root.join('config','data_definitions','events','*.yml')
      DataCycleCore::MasterData::ImportTemplates.new.import(path.to_s, DataCycleCore::Event)
    end

    desc "replace the data-definitions of all data-types in the Database with the templates in the Database"
    task :update_all_templates => [:environment] do
      puts "updating templates:"
      DataCycleCore.content_tables.each do |content_table|
        data_object = "DataCycleCore::#{content_table.classify}".safe_constantize
        data_object.where(template: true).each do |template_object|
          template_name = template_object.headline
          data_count = data_object.where(template: false).where("metadata #>> '{validation, name}' = ?", template_name).count
          puts "#{content_table.ljust(25)} | #{template_name.ljust(25)} | #{data_count.to_s.rjust(10)}"

          strategy = DataCycleCore::Update::UpdateTemplate
          DataCycleCore::Update::Update.new(type: data_object, template: template_object, strategy: strategy, transformation: nil)
        end
      end
    end

    desc "update weigths (boost) in search table"
    task :update_search => [:environment] do
      puts "#{'content_class'.ljust(30)} | #{'data_definition_name'.ljust(25)} | #{'#entries'.ljust(10)} | #{'new weight'}"
      puts '-'*84
      DataCycleCore.content_tables.each do |content_table|
        data_object = "DataCycleCore::#{content_table.classify}".safe_constantize
        data_object.where(template: true).each do |template_object|
          template_name = template_object.headline
          boost = template_object.metadata['validation']['boost']

          unless boost.blank?
            search_entries = DataCycleCore::Search.where(content_data_type: data_object.to_s, data_type: template_name).count

            connection = ActiveRecord::Base.connection
            sql_update = "UPDATE searches SET boost = #{boost} WHERE content_data_type = '#{data_object.to_s}' AND data_type = '#{template_name}'"
            connection.exec_query(sql_update)
          end

          puts "#{data_object.to_s.ljust(30)} | #{template_name.ljust(25)} | #{search_entries.to_s.rjust(10)} | #{(boost||'no search').to_s.rjust(10)}"
        end
      end
    end

    desc "replace a given data-definition with its recent template for a content_table"
    task :update_template, [:content_table_name, :template_name] => [:environment] do |t, args|
      unless DataCycleCore.content_tables.include?(args[:content_table_name])
        puts "ERROR: only the following content_table_names are known to the system:"
        puts "#{DataCycleCore.content_tables}"
        exit -1
      end

      data_object = "DataCycleCore::#{args[:content_table_name].classify}".safe_constantize
      template = data_object.find_by(headline: args[:template_name], template: true)

      if template.nil?
        puts "ERROR: template not found. For the given #{args[:content_table_name]} table only the following templates are available:"
        puts data_object.where(template: true).map(&:headline)
        exit -1
      end

      type = data_object
      strategy = DataCycleCore::Update::UpdateTemplate
      transformation = nil

      DataCycleCore::Update::Update.new(type: type, template: template, strategy: strategy, transformation: transformation)
    end


    desc "DEBUG: hook to wire custom data update for a given content_table_name/template_name"
    task :update_data, [:content_table_name, :template_name] => [:environment] do |t, args|
      unless DataCycleCore.content_tables.include?(args[:content_table_name])
        puts "ERROR: only the following content_table_names are known to the system:"
        puts "#{DataCycleCore.content_tables}"
        exit -1
      end

      data_object = "DataCycleCore::#{args[:content_table_name].classify}".safe_constantize
      template = data_object.find_by(headline: args[:template_name], template: true)

      if template.nil?
        puts "ERROR: template not found. For the given #{args[:content_table_name]} table only the following templates are available:"
        puts data_object.where(template: true).map(&:headline)
        exit -1
      end

      type = data_object
      strategy = DataCycleCore::Update::UpdateData
      transformation = nil

      DataCycleCore::Update::Update.new(type: type, template: template, strategy: strategy, transformation: transformation)
    end
  end

end
