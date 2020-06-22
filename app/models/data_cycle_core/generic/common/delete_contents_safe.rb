# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DeleteContentsSafe
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object.tap { |obj| obj.mode = :full },
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({ "dump.#{locale}.deleted_at": { '$exists': true } }.merge(source_filter.with_evaluated_values))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          last_successful_import = utility_object.external_source.last_successful_import || Time.zone.now - 20.years
          last_successful_download = utility_object.external_source.last_successful_download || Time.zone.now - 20.years
          last_success = [last_successful_import, last_successful_download].compact.min
          return if last_success.present? && last_success > raw_data.dig('deleted_at').in_time_zone

          I18n.with_locale(locale) do
            external_key_path = options.dig(:import, :external_key_path).split('.')
            raise "No external id found! Item:#{raw_data.dig('Id')}, external_key_path: #{external_key_path}" if raw_data.dig(*external_key_path).blank?
            external_key = [options.dig(:import, :external_key_prefix), raw_data.dig(*external_key_path)].join

            DataCycleCore::Thing.find_by(
              external_source_id: utility_object.external_source.id,
              external_key: external_key
            ).try(:destroy_content, save_history: true, destroy_linked: true)
          end
        end
      end
    end
  end
end
