# frozen_string_literal: true

module DataCycleCore
  module Generic
    module ImxPlatform
      module ImportPoi
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(
            I18n.with_locale(locale) { source_filter.with_evaluated_values }
              .merge(
                "dump.#{locale}": { '$exists': true },
                "dump.#{locale}.deleted_at": { '$exists': false }
              )
          )
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          return if raw_data.blank?

          I18n.with_locale(locale) do
            if raw_data.dig('media').present?
              Array.wrap(raw_data.dig('media')).each do |image_data|
                DataCycleCore::Generic::ImxPlatform::Processing.process_image(
                  utility_object,
                  image_data,
                  options.dig(:import, :transformations, :image)
                )
              end
            end

            DataCycleCore::Generic::ImxPlatform::Processing.process_poi(
              utility_object,
              raw_data,
              options.dig(:import, :transformations, :place)
            )
          end
        end
      end
    end
  end
end
