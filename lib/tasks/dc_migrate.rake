# frozen_string_literal: true

namespace :dc do
  namespace :migrate do
    desc 'move external_source_id and external_key from things to external_system_syncs'
    task :external_source_to_system, [:external_system_id] => :environment do |_, args|
      external_system_id = args[:external_system_id]

      abort('External System Id missing!') if external_system_id.blank?

      contents = DataCycleCore::Thing.where(external_source_id: external_system_id)

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'MIGRATING: things')

      contents.find_each do |content|
        content.external_source_to_external_system_syncs

        progressbar.increment
      end

      schedules = DataCycleCore::Schedule.where(external_source_id: external_system_id)
      puts "MIGRATING: schedules (#{schedules.size})..."
      schedules.update_all(external_source_id: nil, external_key: nil)

      classifications = DataCycleCore::Classification.where(external_source_id: external_system_id)
      puts "MIGRATING: classifications (#{classifications.size})..."
      classifications.update_all(external_source_id: nil, external_key: nil)

      classification_trees = DataCycleCore::ClassificationTreeLabel.where(external_source_id: external_system_id)
      puts "MIGRATING: classification_trees (#{classification_trees.size})..."
      classification_trees.update_all(external_source_id: nil)

      classification_groups = DataCycleCore::ClassificationGroup.where(external_source_id: external_system_id)
      puts "MIGRATING: classification_groups (#{classification_groups.size})..."
      classification_groups.update_all(external_source_id: nil)

      classification_aliases = DataCycleCore::ClassificationAlias.where(external_source_id: external_system_id)
      puts "MIGRATING: classification_aliases (#{classification_aliases.size})..."
      classification_aliases.update_all(external_source_id: nil)

      puts 'MIGRATION SUCCESSFUL'
    end

    desc 'download external assets into dataCycle for things with external_system_id'
    task :download_external_assets, [:external_system_id] => :environment do |_, args|
      logger = Logger.new('log/download_assets.log')
      logger.info('Started Downloading...')

      external_system_id = args[:external_system_id]
      allowed_template_names = DataCycleCore::Thing.where(template: true).where("things.schema -> 'properties' ->> 'asset' IS NOT NULL").pluck(:template_name)

      if external_system_id.blank? || allowed_template_names.blank?
        error = 'external_system_id not given or no viable Templates found'
        logger.error(error) && abort(error)
      end

      asset_sql = <<-SQL.squish
        NOT EXISTS (
          SELECT FROM assets
          INNER JOIN asset_contents
          ON asset_contents.asset_id = assets.id
          WHERE asset_contents.content_data_id = things.id
        )
      SQL

      contents = DataCycleCore::Thing.by_external_system(external_system_id).where(template_name: allowed_template_names).where(asset_sql)

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'MIGRATING: things')
      logger.info("DOWNLOADING: assets for #{contents.size} things...")

      contents.find_each do |content|
        I18n.with_locale(content.first_available_locale) do
          asset_type = content.schema&.dig('properties', 'asset', 'asset_type')
          logger.warn("missing asset_type for #{content.id}") && next if asset_type.blank?

          file_url = content.try(:content_url)
          logger.warn("missing content_url for #{content.id}") && next if file_url.blank?

          asset = DataCycleCore.asset_objects.find { |a| a == "DataCycleCore::#{asset_type.classify}" }&.safe_constantize&.new(name: content.title, remote_file_url: file_url)

          logger.error("asset for #{content.id} not saved: #{asset.errors&.full_messages}") && next unless asset&.save

          content.external_source_to_external_system_syncs('duplicate')

          valid = content.set_data_hash(
            data_hash: {
              asset: asset.id,
              url: nil
            },
            partial_update: true,
            prevent_history: true,
            update_search_all: false
          )

          if valid
            logger.info("Successfully loaded asset for #{content.id} from #{file_url}")
          else
            logger.error("Error saving content: #{content.errors.messages}")
          end

          progressbar.increment
        end
      end

      logger.info('DOWNLOAD SUCCESSFUL')
    end

    desc 'migrate embedded Öffnungszeit to opening_time'
    task migrate_opening_hours: :environment do
      description_template = DataCycleCore::Thing.find_by(template: true, template_name: 'Öffnungszeit - Beschreibung')

      contents = DataCycleCore::Thing.where(template: false, template_name: 'Öffnungszeit')
      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Öffnungszeit')

      contents.find_each do |content|
        next progressbar.increment unless content.embedded?

        thing_relation = content.content_content_b.find_by(relation_a: ['opening_hours_specification', 'dining_hours_specification'])

        next progressbar.increment if thing_relation.nil?

        content.time.find_each do |time_content|
          schedule = DataCycleCore::Schedule.new({
            thing_id: thing_relation.content_a_id,
            relation: thing_relation.relation_a
          })
          duration = DataCycleCore::Schedule.time_to_duration(time_content.opens, time_content.closes)

          if content.validity&.valid_from.nil? && content.validity&.valid_to.nil?
            start_time = "2021-01-01 #{time_content.opens}".in_time_zone
            until_time = '2024-01-01'.in_time_zone
          else
            start_time = "#{content.validity&.valid_from} #{time_content.opens}".in_time_zone
            until_time = content.validity.valid_through&.in_time_zone&.end_of_day || 3.years.from_now.in_time_zone.end_of_day
          end

          schedule.from_hash({
            start_time: {
              time: start_time.to_s,
              zone: start_time.time_zone.name
            },
            duration: duration,
            rrules: [{
              rule_type: 'IceCube::WeeklyRule',
              validations: {
                day: content.day_of_week&.pluck(:uri)&.map { |d| DataCycleCore::Schedule::DAY_OF_WEEK_MAPPING.key(d) }
              },
              until: until_time
            }]
          }.deep_reject { |_, v| v.blank? && !v.is_a?(FalseClass) }.with_indifferent_access)

          schedule.save!
        end

        content.available_locales.each do |locale|
          I18n.with_locale(locale) do
            next if content.description.blank?

            description_content = DataCycleCore::Thing.new
            description_content.schema = description_template.schema
            description_content.template_name = description_template.template_name
            description_content.save!

            from_date = content.validity&.valid_from&.in_time_zone&.beginning_of_day || Time.zone.now.beginning_of_day
            duration = 1.day.to_i

            if content.validity&.valid_through.present?
              duration = content.validity.valid_through.in_time_zone.change({ hour: 23, min: 59, sec: 59 }) - from_date
            else
              rrules = [{
                rule_type: 'IceCube::DailyRule'
              }]
            end

            description_content.set_data_hash(data_hash: {
              description: content.description,
              validity_schedule: [{
                start_time: {
                  time: from_date.to_s,
                  zone: from_date.time_zone.name
                },
                duration: duration,
                rrules: rrules
              }.with_indifferent_access]
            }, prevent_history: true, new_content: true)

            relation_a = thing_relation.relation_a == 'opening_hours_specification' ? 'opening_hours_description' : 'dining_hours_description'

            DataCycleCore::ContentContent.create!({
              content_a_id: thing_relation.content_a_id,
              relation_a: relation_a,
              order_a: thing_relation.order_a,
              content_b_id: description_content.id
            })
          end
        end

        content.destroy_children
        content.destroy
        progressbar.increment
      end
    end

    desc 'migrate event places from Örtlichkeit to POI'
    task ortlichkeit_to_poi: :environment do
      poi_class = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Inhaltstypen', 'POI')
      poi_template = DataCycleCore::Thing.find_by(template: true, template_name: 'POI')

      systems = ['feratel']
      systems.each do |identifier|
        es = DataCycleCore::ExternalSystem.find_by(identifier: identifier)
        next if es.blank?
        DataCycleCore::Thing.where(template_name: 'Örtlichkeit', external_source_id: es.id).each do |place|
          # update data-type
          DataCycleCore::ClassificationContent.where(content_data_id: place.id, relation: 'data_type').update_all(classification_id: poi_class)
          # update template, template definition
          place.template_name = poi_template.template_name
          place.schema = poi_template.schema
          place.template_updated_at = Time.zone.now
          place.save
          # update search table
          place.search_languages(true)
        end
      end
    end

    desc 'migrate uniq external_keys for OutdoorActive additionalInformation'
    task oa_external_key: :environment do
      es = DataCycleCore::ExternalSystem.find_by(identifier: 'outdooractive')
      exit(1) if es.blank?

      contents = DataCycleCore::Thing.where(template_name: 'Ergänzende Information', external_source_id: es.id, external_key: nil).includes(:classifications, :translations)
      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Ergänzende Information')
      contents.each do |item|
        desc = item.classifications.first.name
        locale = item.available_locales.first
        parent_external_key = DataCycleCore::ContentContent.where(content_b_id: item.id).first.content_a.external_key
        item.external_key = "#{desc}:#{locale}:#{parent_external_key}"
        item.save!(touch: false)
        progressbar.increment
      end
    end

    desc 'rebuild schedule_occurrences'
    task rebuild_schedule_occurrences: :environment do
      rebuild_occurrences_sql = <<-SQL
        TRUNCATE schedule_occurrences;

        SELECT
          generate_schedule_occurences (ARRAY_AGG(id))
        FROM
          schedules;
      SQL

      ActiveRecord::Base.connection.execute(rebuild_occurrences_sql)
    end

    desc 'remove multiple BYYEARDAY in schedules'
    task remove_multiple_byyearday: :environment do
      byyearday_sql = <<-SQL
        UPDATE
          schedules
        SET
          rrule = REPLACE(rrule, 'BYYEARDAY=' || array_to_string(get_byyearday (rrule::rrule), ','),
            'BYYEARDAY=' || (get_byyearday (rrule::rrule))[1])
        WHERE
          array_length(get_byyearday (rrule::rrule), 1) > 1;
      SQL

      ActiveRecord::Base.connection.execute(byyearday_sql)
    end
  end
end
