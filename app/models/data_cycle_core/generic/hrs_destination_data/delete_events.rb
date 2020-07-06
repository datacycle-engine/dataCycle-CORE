# frozen_string_literal: true

module DataCycleCore
  module Generic
    module HrsDestinationData
      module DeleteEvents
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object.tap { |obj| obj.mode = :full },
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options.merge({ iterator_type: :aggregate })
          )
        end

        def self.load_contents(mongo_item, _locale, _source_filter)
          # hardcoded locale = de
          mongo_item.collection.aggregate(
            [
              { '$match': { _id: { '$exists': true }, 'dump.de.deleted_at': { '$exists': true } } },
              { '$group': { _id: '$dump.de.event.id', dates: { '$addToSet': '$dump.de.date' }, dump: { '$last': '$dump' } } },
              { '$addFields': { 'dump.de.dates': '$dates' } }
            ]
          )
          # db.events.aggregate([
          #   { $match: { _id: { $exists: true }, 'dump.de.deleted_at': { $exists: true } } },
          #   { $group: { _id: '$dump.de.event.id', dates: { $addToSet: '$dump.de.date'}, dump: { $last: '$dump'}}},
          #   { $addFields: { 'dump.de.dates': '$dates' } }
          #  ])
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          last_successful_import = utility_object.external_source.last_successful_import || Time.zone.now - 20.years
          last_successful_download = utility_object.external_source.last_successful_download || Time.zone.now - 20.years
          last_success = [last_successful_import, last_successful_download].compact.min
          return if last_success.present? && last_success > raw_data.dig('deleted_at').in_time_zone

          I18n.with_locale(locale) do
            external_key_path = options.dig(:import, :external_key_path).split('.')
            raise "HRS DD delete Events: No external id found! Item:#{raw_data.dig('Id')}, external_key_path: #{external_key_path}" if raw_data.dig(*external_key_path).blank?
            external_key = [options.dig(:import, :external_key_prefix), raw_data.dig(*external_key_path)].join

            content = DataCycleCore::Thing.find_by(external_source_id: utility_object.external_source.id, external_key: external_key)
            return if content.blank?

            content_schedule = content.event_schedule.first
            content_dates = content_schedule.schedule_object.all_occurrences.map(&:in_time_zone).sort
            delete_dates = raw_data.dig('dates').map(&:in_time_zone).sort
            content.try(:destroy_content, save_history: true, destroy_linked: true) if content_dates == delete_dates
          end
        end
      end
    end
  end
end
