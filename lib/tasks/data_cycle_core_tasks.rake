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
        puts 'queuing mails for daily subscribers...'
        puts "frequency: #{args.frequency}"
        puts "Users for interval (#{args.frequency}): #{DataCycleCore::User.where(notification_frequency: args.frequency).size}"

        DataCycleCore::User.where(notification_frequency: args.frequency, locked_at: nil).each do |user|
          changed_content_ids = user.subscriptions.things.reject { |c| c.as_of(1.send(args.frequency).ago).try(:history?) == false }.pluck(:id)

          puts "Subscriptions with changes: #{changed_content_ids.size}"

          user.send_notification changed_content_ids if changed_content_ids.any?
        end
      end
    end
  end

  namespace :reports do
    desc 'send download report via email'
    task :send_report, [:recipient, :report_identifier, :format] => [:environment] do |_, args|
      recipient = args.fetch(:recipient, nil)
      unless recipient
        puts 'Recipient is required!'
        exit(-1)
      end
      DataCycleCore::ReportMailer.notify(
        identifier: args.fetch(:report_identifier, 'downloads_popular'),
        format: args.fetch(:format, 'xlsx'),
        recipient: recipient
      ).deliver_now
    end
    desc 'send monthly download report from the last month via email'
    task :send_monthly_report, [:recipient, :report_identifier, :format] => [:environment] do |_, args|
      recipient = args.fetch(:recipient, nil)
      unless recipient
        puts 'Recipient is required!'
        exit(-1)
      end
      last_month = Time.zone.now - 1.month
      params = {
        by_month: last_month.month,
        by_year: last_month.year
      }

      DataCycleCore::ReportMailer.notify(
        identifier: args.fetch(:report_identifier, 'downloads_popular'),
        format: args.fetch(:format, 'xlsx'),
        recipient: recipient,
        params: params
      ).deliver_now
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
            data_hash[DataCycleCore::Feature::Releasable.attribute_keys.last] = 'archived automatically.'
            content.set_data_hash(data_hash: data_hash)
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
            content.set_data_hash(data_hash: data_hash)
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
          .where('things.validity_range @> now()')
          .with_content_type('entity').distinct

        contents = contents.where(is_part_of: nil) if ActiveRecord::Base.connection.column_exists?('things', 'is_part_of')

        items_count = contents.size
        puts "UNARCHIVING (release_status) ==> THINGS (#{items_count})"
        progressbar = ProgressBar.create(total: items_count)

        contents.find_each do |content|
          I18n.with_locale(content.first_available_locale) do
            data_hash = {}
            data_hash[DataCycleCore::Feature::Releasable.attribute_keys.first] = [valid_release_id]
            data_hash[DataCycleCore::Feature::Releasable.attribute_keys.last] = 'reactivated automatically.'

            if content.set_data_hash(data_hash: data_hash)
              logger.info("Unarchived (release_status): #{content.id} (THINGS/#{content.template_name}/#{content.translated_locales&.join(', ')})")
            else
              logger.warn("Fehler (#{content.id}): #{content.errors.messages}")
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
          .where('things.validity_range @> now()')
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

              if content.set_data_hash(data_hash: data_hash)
                logger.info("Unarchived (life_cycle): #{content.id} (THINGS/#{content.template_name})")
              else
                logger.warn("Fehler (#{content.id}): #{content.errors.messages}")
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
end
