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
            return unless weather_details.dig('pci').is_a?(::Array)
            if weather_details.present?
              if weather_details.dig('is').present?
                DataCycleCore::Generic::FeratelWebcam::Processing.process_image(
                  utility_object,
                  weather_details.dig('is').merge({ 'rid' => weather_details['rid'], 'type' => 'is', 'url_key' => 'is' }),
                  options.dig(:import, :transformations, :image)
                )
              end

              if weather_details.dig('h').present?
                DataCycleCore::Generic::FeratelWebcam::Processing.process_image(
                  utility_object,
                  weather_details.dig('h').merge({ 'rid' => weather_details['rid'], 'type' => 'h', 'url_key' => 's' }),
                  options.dig(:import, :transformations, :image)
                )
              end

              ['10'].each do |item|
                weather_prediction = Array.wrap(weather_details.dig('w')).detect { |i| i.dig('t') == item }
                next if weather_prediction&.dig('wi').blank?
                DataCycleCore::Generic::FeratelWebcam::Processing.process_weather_classifications(
                  utility_object,
                  weather_prediction,
                  options.dig(:import, :transformations, :weather_classification)
                )

                weather_prediction.dig('wi').each do |forecast|
                  DataCycleCore::Generic::FeratelWebcam::Processing.process_weather_forecast(
                    utility_object,
                    forecast.merge({ 'pci' => weather_details['pci'], 'elevation' => weather_prediction['h'], 'weather_provider' => weather_prediction['pc'] }),
                    options.dig(:import, :transformations, :weather_forecast)
                  )
                end
              end

              DataCycleCore::Generic::FeratelWebcam::Processing.process_place(
                utility_object,
                weather_details,
                options.dig(:import, :transformations, :place)
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
