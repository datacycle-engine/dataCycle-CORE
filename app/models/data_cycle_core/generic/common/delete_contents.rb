# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module DeleteContents
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object.tap { |obj| obj.mode = :full },
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where({ "dump.#{locale}" => { '$exists': true } }.merge(source_filter.with_evaluated_values))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            external_key_path = options.dig(:import, :external_key_path).split('.')

            DataCycleCore::Thing.find_by(
              external_source_id: utility_object.external_source.id,
              external_key: raw_data.dig(*external_key_path)
            ).try(:destroy!)
          end
        end
      end
    end
  end
end
