FIXNUM_MAX = (2**(0.size * 8 - 2) - 1)

delete_classifications = <<-EOS
  DELETE FROM classifications;
  DELETE FROM classification_groups;
  DELETE FROM classification_aliases;
  DELETE FROM classification_trees;
  DELETE FROM classification_tree_labels;
EOS

delete_secondary_data = <<-EOS
  DELETE FROM watch_list_data_hashes;
  DELETE FROM watch_lists;
  DELETE FROM subscriptions;
  DELETE FROM data_links;
EOS

delete_contents = <<-EOS
  DELETE FROM creative_works;
  DELETE FROM creative_work_translations;
  DELETE FROM events;
  DELETE FROM event_translations;
  DELETE FROM persons;
  DELETE FROM person_translations;
  DELETE FROM organizations;
  DELETE FROM organization_translations;
  DELETE FROM places;
  DELETE FROM place_translations;

  DELETE FROM content_contents;

  DELETE FROM classification_contents;
  DELETE FROM searches;

  DELETE FROM overlays;
  DELETE FROM tags;
  DELETE FROM overlay_place_tags;
EOS

delete_content_histories = <<-EOS
  DELETE FROM creative_work_histories;
  DELETE FROM creative_work_history_translations;
  DELETE FROM event_histories;
  DELETE FROM event_history_translations;
  DELETE FROM person_histories;
  DELETE FROM person_history_translations;
  DELETE FROM organization_histories;
  DELETE FROM organization_history_translations;
  DELETE FROM place_histories;
  DELETE FROM place_history_translations;

  DELETE FROM content_content_histories;

  DELETE FROM classification_content_histories;
EOS

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
    desc 'Remove all data except for configuration data like users'
    task all: :environment do
      ActiveRecord::Base.connection.execute(delete_classifications)
      ActiveRecord::Base.connection.execute(delete_secondary_data)
      ActiveRecord::Base.connection.execute(delete_contents)
      ActiveRecord::Base.connection.execute(delete_content_histories)
    end

    desc 'Remove all contents related data like creative works and places (does not remove classifications)'
    task contents: :environment do
      ActiveRecord::Base.connection.execute(delete_secondary_data)
      ActiveRecord::Base.connection.execute(delete_contents)
      ActiveRecord::Base.connection.execute(delete_content_histories)
    end

    desc 'Remove the history of all content data'
    task history: :environment do
      ActiveRecord::Base.connection.execute(delete_content_histories)
    end
  end

  namespace :import do
    desc 'List available endpoints for import'
    task list: :environment do
      DataCycleCore::ExternalSource.all.each do |external_source|
        puts "#{external_source.id} - #{external_source.name}"
      end
    end

    desc 'Download and import data from given data source'
    task :perform, [:external_source_id, :max_count] => [:environment] do |_, args|
      options = Hash[{ max_count: FIXNUM_MAX }.merge(args.to_h).map do |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.download(options)
      external_source.import(options)
    end

    desc 'DEBUG: Only download data from given data source'
    task :download, [:external_source_id, :max_count] => [:environment] do |_, args|
      options = Hash[{ max_count: nil }.merge(args.to_h).map do |k, v|
        if k == :max_count && v
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.download(options)
    end

    desc 'DEBUG: Only import (without downloading) data from given data source'
    task :import, [:external_source_id, :max_count] => [:environment] do |_, args|
      options = Hash[{ max_count: FIXNUM_MAX }.merge(args.to_h).map do |k, v|
        if k == :max_count
          [k, v.to_i]
        else
          [k, v]
        end
      end]

      external_source = DataCycleCore::ExternalSource.find(options[:external_source_id])
      external_source.import(options)
    end
  end

  namespace :update do
    desc 'import classifications'
    task import_classifications: [:environment] do
      puts 'importing new classification definitions'
      path = Rails.root.join('config', 'data_definitions', 'classifications.yml')
      DataCycleCore::MasterData::ImportClassifications.import(path.to_s)
    end

    desc 'import all template definitions'
    task import_templates: [:environment] do
      puts 'importing new template definitions'
      errors, duplicates = DataCycleCore::MasterData::ImportTemplates.import_all
      unless duplicates.blank?
        puts 'the following templates had multiple definitions:'
        ap duplicates
      end
      unless errors.blank?
        puts 'the following errors were encountered during import:'
        ap errors
      end
      duplicates.blank? && errors.blank? ? puts('[done] ... looks good') : exit(-1)
    end

    desc 'import all external_source configs'
    task import_external_source_configs: [:environment] do
      puts 'importing new external_source configs'
      errors = DataCycleCore::MasterData::ImportExternalSources.import_all
      if errors.blank?
        puts '[done] ... looks good'
      else
        puts 'the following errors were encountered during import:'
        ap errors
      end
    end

    desc 'replace the data-definitions of all data-types in the Database with the templates in the Database'
    task update_all_templates: [:environment] do
      puts 'updating templates:'
      DataCycleCore.content_tables.each do |content_table|
        data_object = "DataCycleCore::#{content_table.classify}".safe_constantize
        data_object.where(template: true).each do |template_object|
          template_name = template_object.template_name
          data_count = data_object.where(template: false).where("metadata #>> '{validation, name}' = ? OR template_name = ?", template_name, template_name).count
          puts "#{content_table.ljust(25)} | #{template_name.ljust(25)} | #{(data_count || 0).to_s.rjust(10)}"

          strategy = DataCycleCore::Update::UpdateTemplate
          DataCycleCore::Update::Update.new(type: data_object, template: template_object, strategy: strategy, transformation: nil)
        end
      end
    end

    desc 'update weigths (boost) in search table'
    task update_search: [:environment] do
      puts "#{'content_class'.ljust(30)} | #{'data_definition_name'.ljust(25)} | #{'#entries'.ljust(10)} | new weight"
      puts '-' * 84
      DataCycleCore.content_tables.each do |content_table|
        data_object = "DataCycleCore::#{content_table.classify}".safe_constantize
        data_object.where(template: true).each do |template_object|
          template_name = template_object.template_name
          boost = template_object.schema['boost']

          unless boost.blank?
            search_entries = DataCycleCore::Search.where(content_data_type: data_object.to_s, data_type: template_name).count

            connection = ActiveRecord::Base.connection
            sql_update = "UPDATE searches SET boost = #{boost} WHERE content_data_type = '#{data_object}' AND data_type = '#{template_name}'"
            connection.exec_query(sql_update)
          end

          puts "#{data_object.to_s.ljust(30)} | #{template_name.ljust(25)} | #{search_entries.to_s.rjust(10)} | #{(boost || 'no search').to_s.rjust(10)}"
        end
      end
    end

    desc 'replace a given data-definition with its recent template for a content_table'
    task :update_template, [:content_table_name, :template_name] => [:environment] do |_, args|
      unless DataCycleCore.content_tables.include?(args[:content_table_name])
        puts 'ERROR: only the following content_table_names are known to the system:'
        puts DataCycleCore.content_tables.to_s
        exit(-1)
      end

      data_object = "DataCycleCore::#{args[:content_table_name].classify}".safe_constantize
      template = data_object.find_by(template_name: args[:template_name], template: true)

      if template.nil?
        puts "ERROR: template not found. For the given #{args[:content_table_name]} table only the following templates are available:"
        puts data_object.where(template: true).map(&:template_name)
        exit(-1)
      end

      type = data_object
      strategy = DataCycleCore::Update::UpdateTemplate
      transformation = nil

      DataCycleCore::Update::Update.new(type: type, template: template, strategy: strategy, transformation: transformation)
    end

    desc 'DEBUG: hook to wire custom data update for a given content_table_name/template_name'
    task :update_data, [:content_table_name, :template_name] => [:environment] do |_, args|
      unless DataCycleCore.content_tables.include?(args[:content_table_name])
        puts 'ERROR: only the following content_table_names are known to the system:'
        puts DataCycleCore.content_tables.to_s
        exit(-1)
      end

      data_object = "DataCycleCore::#{args[:content_table_name].classify}".safe_constantize
      template = data_object.find_by(template_name: args[:template_name], template: true)

      if template.nil?
        puts "ERROR: template not found. For the given #{args[:content_table_name]} table only the following templates are available:"
        puts data_object.where(template: true).map(&:template_name)
        exit(-1)
      end

      type = data_object
      strategy = DataCycleCore::Update::UpdateData
      transformation = nil

      DataCycleCore::Update::Update.new(type: type, template: template, strategy: strategy, transformation: transformation)
    end

    desc 'delete history of a specific content_table_name/template_name'
    task :delete_history, [:content_table_name, :template_name] => [:environment] do |_, args|
      unless DataCycleCore.content_tables.include?(args[:content_table_name])
        puts 'ERROR: only the following content_table_names are known to the system:'
        puts DataCycleCore.content_tables.to_s
        exit(-1)
      end

      template_object = "DataCycleCore::#{args[:content_table_name].classify}".safe_constantize
      template = template_object.find_by(template_name: args[:template_name], template: true)

      if template.nil?
        puts "ERROR: template not found. For the given #{args[:content_table_name]} table only the following templates are available:"
        puts template_object.where(template: true).map(&:template_name)
        exit(-1)
      end

      data_object = "DataCycleCore::#{args[:content_table_name].classify}::History".safe_constantize
        .where("metadata #>> '{validation, name}' = '#{args[:template_name]}'")

      total_items = data_object.count
      puts "DELETE history for: #{args[:content_table_name]}/#{args[:template_name]} (#{total_items}) - (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
      index = 0

      data_object.find_each do |data_item|
        # progress_bar
        if total_items > 49
          if (index % 500).zero?
            fraction = (index / (total_items / 100.0)).round(0)
            fraction = 100 if fraction > 100
            print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
          end
        else
          fraction = (((index * 1.0) / total_items) * 100.0).round(0)
          fraction = 100 if fraction > 100
          print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
        end
        index += 1

        data_item.destroy_content
        data_item.destroy

        # delete_history
        # data_item.histories.each{ |item|
        #   item.destroy_content
        #   item.destroy
        # }
      end
      puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
    end
  end

  namespace :data_update do
    desc 'update...move schema, template_name to separate field'
    task schema_update: [:environment] do
      temp = Time.zone.now
      puts 'UPDATE'
      puts "BEGIN: (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

      # update content / content_history
      index = 0
      DataCycleCore.content_tables.each do |content_table|
        [content_table, content_table.singularize + '_histories'].each do |table_name|
          content_class = "DataCycleCore::#{content_table.classify}"
          content_class += '::History' if table_name.end_with?('_histories')
          items_count = content_class.constantize.count
          puts "UPDATING ==> #{content_class} (#{items_count})"
          content = table_name
          sql = <<-EOS
            WITH t AS (
              SELECT
                id,
                metadata #> '{validation}' AS schema_data,
                metadata #>> '{validation, name}' AS template_name_data,
                metadata - 'validation' AS only_metadata
              FROM #{content}
              WHERE metadata #> '{validation}' IS NOT NULL
            )
            UPDATE #{content}
            SET
              template_name = t.template_name_data,
              schema = t.schema_data,
              metadata = t.only_metadata
            FROM t
            WHERE #{content}.id = t.id;
          EOS
          # pp sql
          ActiveRecord::Base.connection.execute(sql)
        end
      end

      Rake::Task['data_cycle_core:update:import_templates'].invoke
      Rake::Task['data_cycle_core:update:update_all_templates'].invoke

      puts 'END'
      puts "--> UPDATE time: #{((Time.zone.now - temp) / 60).to_i} min"
    end
  end

  namespace :notifications do
    desc 'send subscriber notification emails'
    task :send, [:frequency] => [:environment] do |_t, args|
      if args.frequency
        puts 'sending mails for daily subscribers...'
        puts "frequency: #{args.frequency}"
        puts "Users for interval (#{args.frequency}): #{DataCycleCore::User.where(notification_frequency: args.frequency).size}"

        DataCycleCore::User.where(notification_frequency: args.frequency).each do |user|
          subcribed_with_changes = user.subscriptions.map(&:subscribable).reject { |c| c.as_of(1.send(args.frequency).ago).try(:is_history?) == false }

          puts "Subscriptions with changes: #{subcribed_with_changes.size}"

          if subcribed_with_changes.size.positive?
            user.send_notification subcribed_with_changes
          end
        end
      end
    end
  end
end
