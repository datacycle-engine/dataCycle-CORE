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

        DataCycleCore::User.where(notification_frequency: args.frequency, locked_at: nil).each do |user|
          subcribed_with_changes = user.subscriptions.map(&:subscribable).reject { |c| c.as_of(1.send(args.frequency).ago).try(:history?) == false }

          puts "Subscriptions with changes: #{subcribed_with_changes.size}"

          user.send_notification subcribed_with_changes if subcribed_with_changes.size.positive?
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

      expired_contents = DataCycleCore::Thing.where('upper(validity_range) < ?', Date.current)

      if DataCycleCore::Feature::Releasable.attribute_keys.present? && archive_release_id.present?
        contents = expired_contents
          .expired_not_release_id(archive_release_id)
          .with_content_type('entity').uniq

        items_count = contents.size
        puts "ARCHIVING (release_status) ==> THINGS (#{items_count})"
        progressbar = ProgressBar.create(total: items_count)

        contents.find_each do |content|
          I18n.with_locale(content.first_available_locale) do
            data_hash = {}
            data_hash[DataCycleCore::Feature::Releasable.attribute_keys.first] = [archive_release_id]
            data_hash[DataCycleCore::Feature::Releasable.attribute_keys.last] = I18n.t('common.archived', locale: DataCycleCore.ui_language)
            content.set_data_hash(data_hash: data_hash, partial_update: true)
            logger.info("Archived (release_status): #{content.id} (THINGS/#{content.template_name}/#{content.translated_locales&.join(', ')})")
          end
          progressbar.increment
        end
      else
        logger.warn('No Release found.')
      end

      if DataCycleCore::Feature::LifeCycle.attribute_keys.present? && archive_life_cycle_id.present?
        contents = expired_contents
          .expired_not_life_cycle_id(archive_life_cycle_id)
          .with_content_type('entity').distinct

        contents = contents.where(is_part_of: nil) if ActiveRecord::Base.connection.column_exists?('things', 'is_part_of')

        items_count = contents.size
        puts "ARCHIVING (life_cycle) ==> THINGS (#{items_count})"
        progressbar = ProgressBar.create(total: items_count)

        contents.find_each do |content|
          I18n.with_locale(content.first_available_locale) do
            data_hash = {}
            data_hash[DataCycleCore::Feature::LifeCycle.attribute_keys.first] = [archive_life_cycle_id]
            content.set_data_hash(data_hash: data_hash, partial_update: true)
            logger.info("Archived (life_cycle): #{content.id} (THINGS/#{content.template_name}/#{content.translated_locales&.join(', ')})")
          end
          progressbar.increment
        end
      else
        logger.warn('Life_cycle configuration missing.')
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

      if DataCycleCore::Feature::Releasable.attribute_keys.present? && archive_release_id.present?
        contents = DataCycleCore::Thing.joins(:classifications)
          .where(template_name: ['Bild', 'Video'], classifications: { id: archive_release_id })
          .where("metadata ->> 'validity_period' IS NULL OR ((metadata -> 'validity_period' ->> 'valid_from' IS NULL OR metadata -> 'validity_period' ->> 'valid_from' < :today) AND (metadata -> 'validity_period' ->> 'valid_until' IS NULL OR metadata -> 'validity_period' ->> 'valid_until' > :today))", today: Date.current)
          .with_content_type('entity').distinct

        contents = contents.where(is_part_of: nil) if ActiveRecord::Base.connection.column_exists?('things', 'is_part_of')

        items_count = contents.size
        puts "UNARCHIVING (release_status) ==> THINGS (#{items_count})"
        progressbar = ProgressBar.create(total: items_count)

        contents.find_each do |content|
          I18n.with_locale(content.first_available_locale) do
            data_hash = {}
            data_hash[DataCycleCore::Feature::Releasable.attribute_keys.first] = [valid_release_id]
            data_hash[DataCycleCore::Feature::Releasable.attribute_keys.last] = I18n.t('common.unarchived', locale: DataCycleCore.ui_language)
            errors = content.set_data_hash(data_hash: data_hash, partial_update: true)
            if errors[:error].present?
              logger.warn("Fehler (#{content.id}): #{errors[:error]}")
            else
              logger.info("Unarchived (release_status): #{content.id} (THINGS/#{content.template_name}/#{content.translated_locales&.join(', ')})")
            end
          end
          progressbar.increment
        end
      else
        logger.warn('No Release found.')
      end

      if DataCycleCore::Feature::LifeCycle.attribute_keys.present? && archive_life_cycle_id.present?
        contents = DataCycleCore::Thing.joins(:classifications)
          .where(template_name: ['Bild', 'Video'], classifications: { id: archive_life_cycle_id })
          .where("metadata ->> 'validity_period' IS NULL OR ((metadata -> 'validity_period' ->> 'valid_from' IS NULL OR metadata -> 'validity_period' ->> 'valid_from' < :today) AND (metadata -> 'validity_period' ->> 'valid_until' IS NULL OR metadata -> 'validity_period' ->> 'valid_until' > :today))", today: Date.current)
          .with_content_type('entity').distinct

        contents = contents.where(is_part_of: nil) if ActiveRecord::Base.connection.column_exists?('things', 'is_part_of')

        items_count = contents.size
        puts "UNARCHIVING (life_cycle) ==> THINGS (#{items_count})"
        progressbar = ProgressBar.create(total: items_count)

        contents.find_each do |content|
          begin
            I18n.with_locale(content.first_available_locale) do
              data_hash = {}
              data_hash[DataCycleCore::Feature::LifeCycle.attribute_keys.first] = [valid_life_cycle_id]
              errors = content.set_data_hash(data_hash: data_hash, partial_update: true)
              if errors[:error].present?
                logger.warn("Fehler (#{content.id}): #{errors[:error]}")
              else
                logger.info("Unarchived (life_cycle): #{content.id} (THINGS/#{content.template_name})")
              end
            end
          rescue StandardError => e
            logger.warn "Error at #{content.id} (THINGS/#{content.template_name})"
            logger.warn e
          end
          progressbar.increment
        end
      else
        logger.warn('Life_cycle configuration missing.')
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
    desc 'Merge duplicates of classifications'
    task :merge_duplicate_classifications, [:classification_tree_name] => :environment do |_, args|
      duplicates = DataCycleCore::ClassificationAlias
        .joins('join classification_alias_paths on classification_alias_paths.id = classification_aliases.id AND classification_aliases.deleted_at is null')
        .includes(:classification_tree_label, :primary_classification, :classification_tree)
        .select('array_agg(classifications.id), classification_alias_paths.full_path_names, classification_alias_paths.ancestor_ids')
        .where("classification_tree_labels.name = '#{args.classification_tree_name}' AND NOT EXISTS (SELECT FROM classification_alias_paths cap2 WHERE classification_alias_paths.id = cap2.ancestor_ids[1])")
        .group('classification_alias_paths.full_path_names', 'classification_alias_paths.ancestor_ids')
        .having('COUNT(*) > 1')
        .pluck('array_agg(classifications.id), classification_alias_paths.full_path_names, classification_alias_paths.ancestor_ids')

      puts "Merging #{duplicates.size} duplicated classifications of Classification Tree: #{args.classification_tree_name} ... "

      duplicates.each do |d|
        duplicate_ids = d[0]
        original_id = duplicate_ids[0]
        original_content_ids = DataCycleCore::ClassificationContent.where(classification_id: original_id).map(&:content_data_id)

        puts "Merging #{duplicate_ids.size} duplicates of  #{d[1].reverse} ... "

        duplicate_ids.drop(1).compact.each do |duplicate_id|
          original_id_alias = DataCycleCore::Classification.find(original_id).primary_classification_alias
          duplicate_id_alias = DataCycleCore::Classification.find(duplicate_id).primary_classification_alias

          puts "Replacing duplicate #{duplicate_id} with original #{original_id}"

          DataCycleCore::ClassificationContent.where(classification_id: duplicate_id)&.find_each do |cc|
            if original_content_ids.include? cc.content_data_id
              cc.destroy
            else
              cc.update_columns(classification_id: original_id) # rubocop:disable Rails/SkipsModelValidations
              # prevent error due to multiple tagging
              original_content_ids.push(cc.content_data_id)
            end
          end

          DataCycleCore::ClassificationContent::History.where(classification_id: duplicate_id).update_all(classification_id: original_id)

          DataCycleCore::StoredFilter.update_all("parameters = replace(parameters::text, '#{duplicate_id_alias.id}', '#{original_id_alias.id}')::jsonb")

          DataCycleCore::Search.update_all("classification_aliases_mapping = array_replace(classification_aliases_mapping, '#{duplicate_id_alias.id}', '#{original_id_alias.id}')")

          DataCycleCore::ClassificationAlias.find(duplicate_id_alias.id).destroy
        end

        puts "Merging #{duplicate_ids.size} duplicates of  #{d[1].reverse} ... [DONE]"
      end

      puts "Merging #{duplicates.size} duplicated classifications of Classification Tree: #{args.classification_tree_name} ... [DONE]"
    end
  end

  namespace :refactor do
    desc 'import and update all templates'
    task :import_update_all_templates, [:templates] => :environment do |_, args|
      template_names = args.fetch(:templates, nil)&.split('|')&.map(&:squish)
      temp = Time.zone.now

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:import_templates"].invoke

      Rake::Task["#{ENV['CORE_RAKE_PREFIX']}dc:check:invalid_overlay_definitions"].invoke

      if template_names.present?
        template_names.each do |template_name|
          Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:update_template_sql"].invoke(template_name, false)
          Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:update_template_sql"].reenable
        end
      else
        Rake::Task["#{ENV['CORE_RAKE_PREFIX']}data_cycle_core:update:update_all_templates_sql"].invoke(false)
      end

      puts 'END'
      puts "--> MIGRATION time: #{(Time.zone.now - temp)} sec"
    end
  end
end
