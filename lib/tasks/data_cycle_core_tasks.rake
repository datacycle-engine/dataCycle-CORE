# frozen_string_literal: true

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

delete_soft_deleted_classifications = <<-EOS
  DELETE FROM classifications WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_groups WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_aliases WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_trees WHERE deleted_at IS NOT NULL;
  DELETE FROM classification_tree_labels WHERE deleted_at IS NOT NULL;
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

    desc 'Remove all soft-deleted classification data (paranoid)'
    task contents: :environment do
      ActiveRecord::Base.connection.execute(delete_soft_deleted_classifications)
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
      if duplicates.present?
        puts 'INFO: the following templates had multiple definitions:'
        ap duplicates
      end
      if errors.present?
        puts 'the following errors were encountered during import:'
        ap errors
      end
      errors.blank? ? puts('[done] ... looks good') : exit(-1)
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

    desc 'recreate the entries in the search table for all data-types in the Database'
    task rebuild_search: [:environment] do
      puts 'updating search:'
      DataCycleCore.content_tables.each do |content_table|
        data_object = "DataCycleCore::#{content_table.classify}".safe_constantize
        data_object.where(template: true).each do |template_object|
          template_name = template_object.template_name
          data_count = data_object.where(template: false).where('template_name = ?', template_name).count
          puts "#{content_table.ljust(25)} | #{template_name.ljust(25)} | #{(data_count || 0).to_s.rjust(10)}"

          strategy = DataCycleCore::Update::UpdateSearch
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

          if boost.present?
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

    desc '[NEW] replace the data-definitions of all data-types in the Database with the templates in the Database'
    task :update_all_templates_sql, [:history] => [:environment] do |_, args|
      temp = Time.zone.now
      DataCycleCore.content_tables.each do |content_table|
        data_object = "DataCycleCore::#{content_table.classify}".safe_constantize
        data_object.where(template: true).each do |template_object|
          Rake::Task['data_cycle_core:update:update_template_sql'].invoke(content_table, template_object.template_name, args.fetch(:history, false))
          Rake::Task['data_cycle_core:update:update_template_sql'].reenable
        end
      end
      puts "total time: #{((Time.zone.now - temp).to_s + ' sec').rjust(20)} \r"
    end

    desc '[NEW] replace a given data-definition with its recent template for a content_table'
    task :update_template_sql, [:content_table_name, :template_name, :history] => [:environment] do |_, args|
      unless DataCycleCore.content_tables.include?(args[:content_table_name])
        puts 'ERROR: only the following content_table_names are known to the system:'
        puts DataCycleCore.content_tables.to_s
        exit(-1)
      end

      data_object = "DataCycleCore::#{args[:content_table_name].classify}".safe_constantize
      template = data_object.find_by(template_name: args[:template_name], template: true)
      total_items = data_object.where(template_name: args[:template_name], template: false).count

      if template.nil?
        puts "ERROR: template not found. For the given #{args[:content_table_name]} table only the following templates are available:"
        puts data_object.where(template: true).map(&:template_name)
        exit(-1)
      end

      temp = Time.zone.now

      update_sql = <<-EOS
        UPDATE #{args[:content_table_name]}
        SET schema = '#{template.schema.to_json}'
        WHERE template_name='#{args[:template_name]}' and template=false
      EOS

      affected_items = ActiveRecord::Base.connection.update(ActiveRecord::Base.send(:sanitize_sql_for_conditions, update_sql))

      puts "#{args[:content_table_name].ljust(25)} | #{args[:template_name].ljust(25)} | #{((affected_items || 0).to_s + ' / ' + (total_items || 0).to_s).ljust(25)} | #{((Time.zone.now - temp).to_s + ' sec').rjust(20)} \r"

      next unless args.fetch(:history, false).to_s == 'true'

      # history update
      history_object = "DataCycleCore::#{args[:content_table_name].classify}::History".safe_constantize
      total_history_items = history_object.where(template_name: args[:template_name], template: false).count

      temp = Time.zone.now

      update_history_sql = <<-EOS
        UPDATE #{history_object.table_name}
        SET schema = '#{template.schema.to_json}'
        WHERE template_name='#{args[:template_name]}' and template=false
      EOS

      affected_history_items = ActiveRecord::Base.connection.update(ActiveRecord::Base.send(:sanitize_sql_for_conditions, update_history_sql))

      puts "#{history_object.table_name.ljust(25)} | #{args[:template_name].ljust(25)} | #{((affected_history_items || 0).to_s + ' / ' + (total_history_items || 0).to_s).ljust(25)} | #{((Time.zone.now - temp).to_s + ' sec').rjust(20)} \r"
    end
  end

  namespace :data_update do
    desc 'update...move schema, template_name to separate field'
    task schema_update: [:environment] do
      temp = Time.zone.now
      puts 'UPDATE'
      puts "BEGIN: (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"

      # update content / content_history
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
          subcribed_with_changes = user.subscriptions.map(&:subscribable).reject { |c| c.as_of(1.send(args.frequency).ago).try(:history?) == false }

          puts "Subscriptions with changes: #{subcribed_with_changes.size}"

          if subcribed_with_changes.size.positive?
            user.send_notification subcribed_with_changes
          end
        end
      end
    end
  end

  namespace :archive do
    desc 'move expired contents to archive'
    task expired: :environment do
      logger = Logger.new('log/archive.log')
      logger.info('Started Archiving...')
      temp = Time.zone.now
      archive_life_cycle_id = DataCycleCore::Classification.find_by(name: DataCycleCore.features.dig(:life_cycle, :ordered)&.last)&.id
      archive_release_id = DataCycleCore::Release.order(release_code: :desc)&.first&.id
      current_user = DataCycleCore::User.find_by('email ILIKE ?', 'admin%')&.id

      ids = DataCycleCore::Search.where('upper(validity_period) < ?', Date.current).map { |s| s.content_data&.id }

      DataCycleCore.content_tables.each do |table_name|
        if archive_release_id.present?
          contents = ('DataCycleCore::' + table_name.singularize.classify).constantize
            .where(id: ids)
            .expired_not_release_id(archive_release_id)
            .with_content_type('entity').uniq

          index = 0
          items_count = contents.size
          puts "ARCHIVING (release_status) ==> #{table_name} (#{items_count})"

          contents.each do |content|
            # progress bar
            if items_count > 49
              if (index % (items_count / 100.0).round(0)).zero?
                fraction = (index / (items_count / 100.0)).round(0)
                fraction = 100 if fraction > 100
                print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
              end
            else
              fraction = (((index * 1.0) / items_count) * 100.0).round(0)
              fraction = 100 if fraction > 100
              print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
            end
            index += 1

            I18n.with_locale(content.first_available_locale) do
              content.set_data_hash(data_hash: content.get_data_hash, current_user: current_user)
              content.translations.update_all(release_id: archive_release_id, release_comment: I18n.t('common.archived', locale: DataCycleCore.ui_language))
              logger.info("Archived (release_status): #{content.id} (#{table_name}/#{content.template_name}/#{content.translated_locales&.join(', ')})")
            end
          end

          puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
        else
          logger.warn('No Release found.')
        end

        if DataCycleCore.features.dig(:life_cycle, :attribute_key).present? && archive_life_cycle_id.present?
          contents = ('DataCycleCore::' + table_name.singularize.classify).constantize
            .where(id: ids)
            .where('classification_contents.relation = ?', DataCycleCore.features.dig(:life_cycle, :attribute_key))
            .expired_not_life_cycle_id(archive_life_cycle_id)
            .with_content_type('entity').distinct

          contents = contents.where(is_part_of: nil) if ActiveRecord::Base.connection.column_exists?(table_name, 'is_part_of')

          index = 0
          items_count = contents.size
          puts "ARCHIVING (life_cycle) ==> #{table_name} (#{items_count})"

          contents.each do |content|
            # progress bar
            if items_count > 49
              if (index % (items_count / 100.0).round(0)).zero?
                fraction = (index / (items_count / 100.0)).round(0)
                fraction = 100 if fraction > 100
                print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
              end
            else
              fraction = (((index * 1.0) / items_count) * 100.0).round(0)
              fraction = 100 if fraction > 100
              print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
            end
            index += 1

            I18n.with_locale(content.first_available_locale) do
              data_hash = content.get_data_hash
              data_hash[DataCycleCore.features.dig(:life_cycle, :attribute_key)] = [archive_life_cycle_id]
              content.set_data_hash(data_hash: data_hash, current_user: current_user)
              logger.info("Archived (life_cycle): #{content.id} (#{table_name}/#{content.template_name}/#{content.translated_locales&.join(', ')})")
            end
          end

          puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
        else
          logger.warn('Life_cycle configuration missing.')
        end
      end
      puts 'END'
      puts "--> ARCHIVING time: #{((Time.zone.now - temp) / 60).to_i} min"
      logger.info("Finished Archiving after #{((Time.zone.now - temp) / 60).to_i} min")
    end
  end

  namespace :unarchive do
    desc 'unarchive valid images/videos'
    task valid: :environment do
      logger = Logger.new('log/unarchive.log')
      logger.info('Started Unarchiving...')
      temp = Time.zone.now
      archive_life_cycle_id = DataCycleCore::Classification.find_by(name: DataCycleCore.features.dig(:life_cycle, :ordered)&.last)&.id
      valid_life_cycle_id = DataCycleCore::Classification.find_by(name: 'Aktuelle Inhalte')&.id
      archive_release_id = DataCycleCore::Release.order(release_code: :desc)&.first&.id
      valid_release_id = DataCycleCore::Release.order(release_code: :desc)&.last&.id
      current_user = DataCycleCore::User.find_by('email ILIKE ?', 'admin%')&.id

      DataCycleCore.content_tables.each do |table_name|
        if archive_release_id.present?
          contents = ('DataCycleCore::' + table_name.singularize.classify).constantize.includes(:translations)
            .where(release_id: archive_release_id, template_name: ['Bild', 'Video'])
            .where("metadata ->> 'validity_period' IS NULL OR ((metadata -> 'validity_period' ->> 'valid_from' IS NULL OR metadata -> 'validity_period' ->> 'valid_from' < :today) AND (metadata -> 'validity_period' ->> 'valid_until' IS NULL OR metadata -> 'validity_period' ->> 'valid_until' > :today))", today: Date.current)
            .with_content_type('entity').distinct

          contents = contents.where(is_part_of: nil) if ActiveRecord::Base.connection.column_exists?(table_name, 'is_part_of')

          index = 0
          items_count = contents.size
          puts "UNARCHIVING (release_status) ==> #{table_name} (#{items_count})"

          contents.find_each do |content|
            # progress bar
            if items_count > 49
              if (index % (items_count / 100.0).round(0)).zero?
                fraction = (index / (items_count / 100.0)).round(0)
                fraction = 100 if fraction > 100
                print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
              end
            else
              fraction = (((index * 1.0) / items_count) * 100.0).round(0)
              fraction = 100 if fraction > 100
              print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
            end
            index += 1

            I18n.with_locale(content.first_available_locale) do
              content.set_data_hash(data_hash: content.get_data_hash, current_user: current_user)
              content.translations.update_all(release_id: valid_release_id, release_comment: I18n.t('common.unarchived', locale: DataCycleCore.ui_language))
              logger.info("Unarchived (release_status): #{content.id} (#{table_name}/#{content.template_name}/#{content.translated_locales&.join(', ')})")
            end
          end

          puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
        else
          logger.warn('No Release found.')
        end

        if DataCycleCore.features.dig(:life_cycle, :attribute_key).present? && archive_life_cycle_id.present?
          contents = ('DataCycleCore::' + table_name.singularize.classify).constantize.joins(:classifications)
            .where(template_name: ['Bild', 'Video'], classifications: { id: archive_life_cycle_id })
            .where("metadata ->> 'validity_period' IS NULL OR ((metadata -> 'validity_period' ->> 'valid_from' IS NULL OR metadata -> 'validity_period' ->> 'valid_from' < :today) AND (metadata -> 'validity_period' ->> 'valid_until' IS NULL OR metadata -> 'validity_period' ->> 'valid_until' > :today))", today: Date.current)
            .with_content_type('entity').distinct

          contents = contents.where(is_part_of: nil) if ActiveRecord::Base.connection.column_exists?(table_name, 'is_part_of')

          # raise contents.to_sql.inspect

          index = 0
          items_count = contents.size
          puts "UNARCHIVING (life_cycle) ==> #{table_name} (#{items_count})"

          contents.find_each do |content|
            # progress bar
            if items_count > 49
              if (index % (items_count / 100.0).round(0)).zero?
                fraction = (index / (items_count / 100.0)).round(0)
                fraction = 100 if fraction > 100
                print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
              end
            else
              fraction = (((index * 1.0) / items_count) * 100.0).round(0)
              fraction = 100 if fraction > 100
              print "[#{'*' * fraction}#{' ' * (100 - fraction)}] #{fraction.to_s.rjust(3)}% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})\r"
            end
            index += 1

            begin
              I18n.with_locale(content.first_available_locale) do
                data_hash = content.get_data_hash
                data_hash[DataCycleCore.features.dig(:life_cycle, :attribute_key)] = [valid_life_cycle_id]
                errors = content.set_data_hash(data_hash: data_hash, current_user: current_user)
                if errors[:error].present?
                  logger.warn("Fehler (#{content.id}): #{errors[:error]}")
                else
                  logger.info("Unarchived (life_cycle): #{content.id} (#{table_name}/#{content.template_name})")
                end
              end
            rescue StandardError => e
              logger.warn "Error at #{content.id} (#{table_name}/#{content.template_name})"
              logger.warn e
            end
          end

          puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
        else
          logger.warn('Life_cycle configuration missing.')
        end
      end
      puts 'END'
      puts "--> UNARCHIVING time: #{((Time.zone.now - temp) / 60).to_i} min"
      logger.info("Finished Unarchiving after #{((Time.zone.now - temp) / 60).to_i} min")
    end
  end

  namespace :external_contents do
    desc 'Merge duplicates of external contents'
    task merge_duplicates: :environment do
      DataCycleCore::Ability::CONTENT_MODELS.each do |model_class|
        duplicated_contents = model_class
          .select(:external_source_id, :external_key)
          .where.not(external_source_id: nil, external_key: nil)
          .group(:external_source_id, :external_key)
          .having('COUNT(*) > 1')

        duplicated_contents_count = duplicated_contents.to_a.size

        puts "\nMerging #{duplicated_contents_count} duplicated external contents of type #{model_class} ... "

        duplicated_contents.each do |duplicated_content|
          contents = model_class.where(external_source_id: duplicated_content.external_source_id,
                                       external_key: duplicated_content.external_key)

          original_id = contents
            .map(&:id)
            .map { |id| [id, DataCycleCore::ContentContent.where(content_b_id: id).count] }
            .sort_by(&:second).reverse
            .map(&:first)
            .first

          duplicate_ids = contents
            .map(&:id)
            .map { |id| [id, DataCycleCore::ContentContent.where(content_b_id: id).count] }
            .sort_by(&:second).reverse
            .map(&:first)
            .drop(1)

          puts " -> Merging #{duplicate_ids.count} duplicates of #{model_class}##{original_id} ..."

          duplicate_ids.each do |duplicate_id|
            DataCycleCore::ContentContent.where(content_b_id: duplicate_id).map(&:content_a).each do |linked_content|
              I18n.with_locale(linked_content.available_locales.first) do
                linked_content.set_data_hash(data_hash: linked_content.get_data_hash)
              end
            end

            DataCycleCore::ContentContent.where(content_b_id: duplicate_id).update_all(content_b_id: original_id)
          end

          puts " -> Merging #{duplicate_ids.count} duplicates of #{model_class}##{original_id} ... [DONE]"

          model_class.where(id: duplicate_ids).destroy_all
        end

        puts "Merging #{duplicated_contents_count} duplicated external contents of type #{model_class} ... [DONE]"
      end

      duplicated_content_relations = DataCycleCore::ContentContent
        .select(:content_a_id, :content_a_type, :relation_a,
                :content_b_id, :content_b_type, :relation_b,
                'MIN(created_at) AS "oldest_creation_date"')
        .group(:content_a_id, :content_a_type, :relation_a, :content_b_id, :content_b_type, :relation_b)
        .having('COUNT(*) > 1')

      duplicated_content_relations_count = duplicated_content_relations.to_a.size

      puts "\nCleaning up #{duplicated_content_relations_count} content relations ... "

      duplicated_content_relations.each do |duplicated_relation|
        DataCycleCore::ContentContent.where(
          content_a_id: duplicated_relation.content_a_id,
          content_a_type: duplicated_relation.content_a_type,
          relation_a: duplicated_relation.relation_a,
          content_b_id: duplicated_relation.content_b_id,
          content_b_type: duplicated_relation.content_b_type,
          relation_b: duplicated_relation.relation_b
        ).where('created_at > ?', duplicated_relation.oldest_creation_date).destroy_all
      end

      puts "Cleaning up #{duplicated_content_relations_count} content relations ... [DONE]"
    end
  end

  namespace :refactor do
    desc 'executes last_updated_by migrations'
    task last_updated_by: :environment do
      temp = Time.zone.now
      DataCycleCore.content_tables.each do |content_table|
        [content_table, content_table.singularize + '_histories'].each do |table_name|
          content_class = "DataCycleCore::#{content_table.classify}"
          content_class += '::History' if table_name.end_with?('_histories')
          data_object = content_class.safe_constantize

          where_string = "metadata #> '{last_updated_by}' IS NOT NULL AND metadata #> '{last_updated_by}' <> 'null'"
          ap data_object.to_s + ' | ' + data_object.where(where_string).count.to_s
          data_object.where(where_string).each do |item|
            user_id = item.metadata['last_updated_by']

            if table_name.end_with?('_histories')
              DataCycleCore::ContentContent::History.create!(
                content_a_history_id: item.id,
                content_a_history_type: data_object.to_s,
                relation_a: 'last_updated_by',
                content_b_history_id: user_id,
                content_b_history_type: 'DataCycleCore::User',
                relation_b: ''
              )
            else
              DataCycleCore::ContentContent.create!(
                content_a_id: item.id,
                content_a_type: data_object.to_s,
                relation_a: 'last_updated_by',
                content_b_id: user_id,
                content_b_type: 'DataCycleCore::User',
                relation_b: ''
              )
            end

            # remove last_updated_by from metadata
            update_sql = <<-EOS
              UPDATE #{table_name}
              SET metadata = metadata - 'last_updated_by'
              WHERE id = '#{item.id}'
            EOS
            ActiveRecord::Base.connection.exec_query(ActiveRecord::Base.send(:sanitize_sql_for_conditions, update_sql))
          end
        end
      end

      puts 'END'
      puts "--> MIGRATION time: #{(Time.zone.now - temp)} sec"
    end

    desc 'executes all migration tasks'
    task migrate_all_templates: :environment do
      temp = Time.zone.now

      Rake::Task['db:migrate'].invoke
      Rake::Task['data_cycle_core:update:import_classifications'].invoke
      Rake::Task['data_cycle_core:update:import_templates'].invoke
      Rake::Task['data_cycle_core:update:import_external_source_configs'].invoke
      # Rake::Task['data_cycle_core:update:update_template_sql'].invoke('places', 'Örtlichkeit')
      Rake::Task['data_cycle_core:update:update_all_templates_sql'].invoke(true)
      Rake::Task['data_cycle_core:refactor:last_updated_by'].invoke

      puts 'END'
      puts "--> MIGRATION time: #{(Time.zone.now - temp)} sec"
    end
  end
end
