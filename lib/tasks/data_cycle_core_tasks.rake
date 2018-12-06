# frozen_string_literal: true

Rake::Task['db:create'].enhance do
  if ENV['RAILS_ENV']
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "pg_trgm";')
    ActiveRecord::Base.connection.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto";')
  else
    ActiveRecord::Base.establish_connection(:development)
      .connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.establish_connection(:development)
      .connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
    ActiveRecord::Base.establish_connection(:development)
      .connection.execute('CREATE EXTENSION IF NOT EXISTS "pg_trgm";')
    ActiveRecord::Base.establish_connection(:development)
      .connection.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto";')

    ActiveRecord::Base.establish_connection(:test)
      .connection.execute('CREATE EXTENSION IF NOT EXISTS "postgis";')
    ActiveRecord::Base.establish_connection(:test)
      .connection.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp";')
    ActiveRecord::Base.establish_connection(:test)
      .connection.execute('CREATE EXTENSION IF NOT EXISTS "pg_trgm";')
    ActiveRecord::Base.establish_connection(:test)
      .connection.execute('CREATE EXTENSION IF NOT EXISTS "pgcrypto";')
  end
end

namespace :data_cycle_core do
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
      archive_life_cycle_id = DataCycleCore::Feature::LifeCycle.ordered_classifications.values&.last&.dig(:id)
      archive_release_id = DataCycleCore::Classification.includes(classification_aliases: :classification_tree_label).find_by(name: DataCycleCore::Feature::Releasable.get_stage('archive'), classification_aliases: { classification_tree_labels: { name: 'Release-Stati' } }).presence&.id

      ids = DataCycleCore::Search.where('upper(validity_period) < ?', Date.current).map { |s| s.content_data&.id }

      ['things'].each do |table_name|
        if DataCycleCore::Feature::Releasable.attribute_keys.present? && archive_release_id.present?
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
              data_hash = content.get_data_hash
              data_hash[DataCycleCore::Feature::Releasable.attribute_keys.first] = [archive_release_id]
              data_hash[DataCycleCore::Feature::Releasable.attribute_keys.last] = I18n.t('common.archived', locale: DataCycleCore.ui_language)
              content.set_data_hash(data_hash: data_hash)
              logger.info("Archived (release_status): #{content.id} (#{table_name}/#{content.template_name}/#{content.translated_locales&.join(', ')})")
            end
          end

          puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
        else
          logger.warn('No Release found.')
        end

        if DataCycleCore::Feature::LifeCycle.attribute_keys.present? && archive_life_cycle_id.present?
          contents = ('DataCycleCore::' + table_name.singularize.classify).constantize
            .where(id: ids)
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
              data_hash[DataCycleCore::Feature::LifeCycle.attribute_keys.first] = [archive_life_cycle_id]
              content.set_data_hash(data_hash: data_hash)
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
      archive_life_cycle_id = DataCycleCore::Feature::LifeCycle.ordered_classifications.values&.last&.dig(:id)
      valid_life_cycle_id = DataCycleCore::Classification.find_by(name: 'Aktuelle Inhalte')&.id

      archive_release_id = DataCycleCore::Classification.includes(classification_aliases: :classification_tree_label).find_by(name: DataCycleCore::Feature::Releasable.get_stage('archive'), classification_aliases: { classification_tree_labels: { name: 'Release-Stati' } }).presence&.id
      valid_release_id = DataCycleCore::Classification.includes(classification_aliases: :classification_tree_label).find_by(name: DataCycleCore::Feature::Releasable.get_stage('valid'), classification_aliases: { classification_tree_labels: { name: 'Release-Stati' } }).presence&.id

      ['things'].each do |table_name|
        if DataCycleCore::Feature::Releasable.attribute_keys.present? && archive_release_id.present?
          contents = ('DataCycleCore::' + table_name.singularize.classify).constantize.joins(:classifications)
            .where(template_name: ['Bild', 'Video'], classifications: { id: archive_release_id })
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
              data_hash = content.get_data_hash
              data_hash[DataCycleCore::Feature::Releasable.attribute_keys.first] = [valid_release_id]
              data_hash[DataCycleCore::Feature::Releasable.attribute_keys.last] = I18n.t('common.unarchived', locale: DataCycleCore.ui_language)
              errors = content.set_data_hash(data_hash: data_hash)
              if errors[:error].present?
                logger.warn("Fehler (#{content.id}): #{errors[:error]}")
              else
                logger.info("Unarchived (release_status): #{content.id} (#{table_name}/#{content.template_name}/#{content.translated_locales&.join(', ')})")
              end
            end
          end

          puts "[#{'*' * 100}] 100% (#{Time.zone.now.strftime('%H:%M:%S.%3N')})"
        else
          logger.warn('No Release found.')
        end

        if DataCycleCore::Feature::LifeCycle.attribute_keys.present? && archive_life_cycle_id.present?
          contents = ('DataCycleCore::' + table_name.singularize.classify).constantize.joins(:classifications)
            .where(template_name: ['Bild', 'Video'], classifications: { id: archive_life_cycle_id })
            .where("metadata ->> 'validity_period' IS NULL OR ((metadata -> 'validity_period' ->> 'valid_from' IS NULL OR metadata -> 'validity_period' ->> 'valid_from' < :today) AND (metadata -> 'validity_period' ->> 'valid_until' IS NULL OR metadata -> 'validity_period' ->> 'valid_until' > :today))", today: Date.current)
            .with_content_type('entity').distinct

          contents = contents.where(is_part_of: nil) if ActiveRecord::Base.connection.column_exists?(table_name, 'is_part_of')

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
                data_hash[DataCycleCore::Feature::LifeCycle.attribute_keys.first] = [valid_life_cycle_id]
                errors = content.set_data_hash(data_hash: data_hash)
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
      ['things'].map { |table| "DataCycleCore::#{table.classify}".constantize }.each do |model_class|
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
        .select(:content_a_id, :relation_a, :content_b_id, 'MIN(created_at) AS "oldest_creation_date"')
        .group(:content_a_id, :relation_a, :content_b_id)
        .having('COUNT(*) > 1')

      duplicated_content_relations_count = duplicated_content_relations.to_a.size

      puts "\nCleaning up #{duplicated_content_relations_count} content relations ... "

      duplicated_content_relations.each do |duplicated_relation|
        DataCycleCore::ContentContent.where(
          content_a_id: duplicated_relation.content_a_id,
          relation_a: duplicated_relation.relation_a,
          content_b_id: duplicated_relation.content_b_id
        ).where('created_at > ?', duplicated_relation.oldest_creation_date).destroy_all
      end

      puts "Cleaning up #{duplicated_content_relations_count} content relations ... [DONE]"
    end
  end

  namespace :refactor do
    desc 'import and update all templates'
    task :import_update_all_templates, [:prefix] => [:environment] do |_, args|
      temp = Time.zone.now
      args[:prefix] ||= ''

      Rake::Task["#{args[:prefix]}data_cycle_core:update:import_templates"].invoke
      Rake::Task["#{args[:prefix]}data_cycle_core:update:update_all_templates_sql"].invoke(false, args[:prefix])

      puts 'END'
      puts "--> MIGRATION time: #{(Time.zone.now - temp)} sec"
    end
  end
end
