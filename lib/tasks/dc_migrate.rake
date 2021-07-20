# frozen_string_literal: true

namespace :dc do
  namespace :migrate do
    desc 'move external_source_id and external_key from things to external_system_syncs'
    task :external_source_to_system, [:external_system_id] => :environment do |_, args|
      external_system_id = args[:external_system_id]

      exit(-1) if external_system_id.blank?

      contents = DataCycleCore::Thing.where(external_source_id: external_system_id).where.not(external_key: nil)

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')

      contents.find_each do |content|
        content.external_source_to_external_system_syncs

        progressbar.increment
      end
    end

    desc 'download external assets into dataCycle'
    task :download_external_assets, [:external_system_id] => :environment do |_, args|
      logger = Logger.new('log/download_assets.log')
      logger.info('Started Downloading...')

      external_system_id = args[:external_system_id]
      allowed_template_names = DataCycleCore::Thing.where(template: true).where("things.schema -> 'properties' ->> 'asset' IS NOT NULL").pluck(:template_name)

      logger.error('External System not found or no viable Templates found') && exit(-1) if external_system_id.blank? || allowed_template_names.blank?

      contents = DataCycleCore::Thing.left_joins(:assets).by_external_system(external_system_id).where(template_name: allowed_template_names).where(assets: { id: nil })

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Progress')
      logger.info("Downloading assets for #{contents.size} contents...")

      contents.find_each do |content|
        I18n.with_locale(content.first_available_locale) do
          asset_type = content.schema&.dig('properties', 'asset', 'asset_type')
          logger.warn("missing asset_type for #{content.id}") && next if asset_type.blank?

          file_url = content.try(:content_url)
          logger.warn("missing content_url for #{content.id}") && next if file_url.blank?

          asset = DataCycleCore.asset_objects.find { |a| a == "DataCycleCore::#{asset_type.classify}" }&.safe_constantize&.new(name: content.title, remote_file_url: file_url)

          logger.error("asset for #{content.id} not saved: #{asset.errors&.full_messages}") && next unless asset&.save

          valid = content.set_data_hash(data_hash: {
            asset: asset.id
          }, partial_update: true, prevent_history: true, update_search_all: false)

          if valid[:error].present?
            logger.error("Error saving content: #{valid[:error]}")
          else
            logger.info("Successfully loaded asset for #{content.id} from #{file_url}")
          end

          progressbar.increment
        end
      end

      logger.info('Finished Downloading...')
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
              duration = content.validity.valid_through.in_time_zone.change({ hour: 23, minute: 59 }) - from_date
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
  end
end
