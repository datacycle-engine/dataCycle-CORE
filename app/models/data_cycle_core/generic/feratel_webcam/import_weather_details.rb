# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module ImportWeatherDetails
        def self.import_data(utility_object:, options:)
          DataCycleCore::Generic::Common::ImportFunctions.import_contents(
            utility_object: utility_object,
            iterator: method(:load_contents).to_proc,
            data_processor: method(:process_content).to_proc,
            options: options
          )
        end

        def self.load_contents(mongo_item, locale, source_filter)
          mongo_item.where(source_filter.with_evaluated_values.merge("dump.#{locale}": { '$exists' => true }))
        end

        def self.process_content(utility_object:, raw_data:, locale:, options:)
          I18n.with_locale(locale) do
            weather_details = raw_data.dig('co', 'pl', 'pcs', 'pc').detect { |i| i.dig('t') == '3' }

            if weather_details.present?
              DataCycleCore::Generic::FeratelWebcam::Processing.process_image(
                utility_object,
                weather_details.dig('is').merge({ 'rid' => weather_details['rid'], 'type' => 'is', 'url_key' => 'is' }),
                options.dig(:import, :transformations, :image)
              )

              DataCycleCore::Generic::FeratelWebcam::Processing.process_image(
                utility_object,
                weather_details.dig('h').merge({ 'rid' => weather_details['rid'], 'type' => 'h', 'url_key' => 's' }),
                options.dig(:import, :transformations, :image)
              )

              DataCycleCore::Generic::FeratelWebcam::Processing.process_weather_details(
                utility_object,
                weather_details,
                options.dig(:import, :transformations, :weather)
              )
            end
          end
        end
      end
    end
  end
end
