# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module Processing
        def self.process_slope(utility_object, raw_data, config)
          ski_region_data = raw_data.dig('co', 'pl', 'pcs', 'pc')&.detect { |i| i.dig('t') == '4' }&.dig('pcc')
          return if ski_region_data.blank?
          ski_region_id = ski_region_data.dig('rid')
          Array.wrap(
            ski_region_data.dig('pccd')
            &.detect { |i| i.dig('t') == '1' }
            &.dig('pccdi', 'sl')
          )&.each do |slope_data|
            DataCycleCore::Generic::Common::ImportFunctions.process_step(
              utility_object: utility_object,
              raw_data: slope_data.merge({ 'ski_region_id' => ski_region_id }),
              transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_slope(utility_object.external_source.id),
              default: { template: 'Piste' },
              config: config
            )
          end
        end

        def self.process_lift(utility_object, raw_data, config)
          ski_region_data = raw_data.dig('co', 'pl', 'pcs', 'pc')&.detect { |i| i.dig('t') == '4' }&.dig('pcc')
          return if ski_region_data.blank?
          ski_region_id = ski_region_data.dig('rid')
          Array.wrap(
            ski_region_data.dig('pccd')
            &.detect { |i| i.dig('t') == '0' }
            &.dig('pccdi', 'sk')
          )&.each do |slope_data|
            DataCycleCore::Generic::Common::ImportFunctions.process_step(
              utility_object: utility_object,
              raw_data: slope_data.merge({ 'ski_region_id' => ski_region_id }),
              transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_lift(utility_object.external_source.id),
              default: { template: 'Lift' },
              config: config
            )
          end
        end

        def self.process_infrastructure(utility_object, raw_data, config)
          ski_region_data = raw_data.dig('co', 'pl', 'pcs', 'pc')&.detect { |i| i.dig('t') == '4' }&.dig('pcc')
          return if ski_region_data.blank?
          ski_region_id = ski_region_data.dig('rid')
          Array.wrap(
            ski_region_data.dig('pccd')
            &.detect { |i| i.dig('t') == '2' }
            &.dig('pccdi', 'if')
          )&.each do |infrastructure_data|
            DataCycleCore::Generic::Common::ImportFunctions.process_step(
              utility_object: utility_object,
              raw_data: infrastructure_data.merge({ 'ski_region_id' => ski_region_id }),
              transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_infrastructure(utility_object.external_source.id),
              default: { template: 'Zusatzangebot' },
              config: config
            )
          end
        end

        def self.process_ski_region(utility_object, raw_data, config)
          ski_region_data = raw_data.dig('co', 'pl', 'pcs', 'pc')&.detect { |i| i.dig('t') == '4' }&.dig('pcc')&.except('pccd')
          return if ski_region_data.blank?
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: ski_region_data,
            transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_ski_region(utility_object.external_source.id),
            default: { template: 'Skigebiet' },
            config: config
          )
        end

        def self.process_weather_details(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_weather_station(utility_object.external_source.id),
            default: { template: 'Wetterstation Feratel' },
            config: config
          )
        end

        def self.process_place(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_place(utility_object.external_source.id),
            default: { template: 'Örtlichkeit' },
            config: config
          )
        end

        def self.process_video(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_video,
            default: { template: 'Video' },
            config: config
          )
        end

        def self.process_image(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_image,
            default: { template: 'Bild' },
            config: config
          )
        end

        def self.process_weather_classifications(utility_object, raw_data, _config)
          weather_prediction = raw_data
          weather_provider = weather_prediction.dig('pc')
          classifications = weather_prediction.dig('wi').map { |ii|
            key = ii.dig('wid').detect { |item| item.dig('t') == '5' }&.dig('v')
            name = ii.dig('wid').detect { |item| item.dig('t') == '6' }&.dig('v')
            {
              name: name,
              external_key: "Feratel Webcams - #{weather_provider} - #{key}",
              tree_name: "Fertael Webcams - #{weather_provider}"
            }
          }.uniq

          classifications_details = weather_prediction.dig('wi').map { |ii|
            detail = ii.dig('wid')&.detect { |item| item.dig('t') == '8' }
            next if detail.blank?
            ['00', '03', '06', '09', '12', '15', '18', '21'].map { |index|
              next if detail["s#{index}"].blank?
              {
                name: detail["s#{index}t"],
                external_key: "Feratel Webcams - #{weather_provider} - #{detail['s' + index]}",
                tree_name: "Fertael Webcams - #{weather_provider}"
              }
            }.compact
          }.compact.flatten.uniq
          classifications += classifications_details

          classifications.compact.uniq.each do |classification_data|
            DataCycleCore::Generic::Common::ImportFunctions.import_classification(
              utility_object: utility_object,
              classification_data: classification_data,
              parent_classification_alias: nil
            )
          end
        end

        def self.process_weather_forecast(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_weather_forecast(utility_object.external_source.id),
            default: { template: 'Wetterprognose' },
            config: config
          )
        end

        def self.process_webcam(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_webcam(utility_object.external_source.id),
            default: { template: 'Webcam' },
            config: config
          )
        end
      end
    end
  end
end
