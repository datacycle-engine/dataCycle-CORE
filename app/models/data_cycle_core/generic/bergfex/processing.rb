# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Bergfex
      module Processing
        def self.process_lake(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Bergfex::Transformations.bergfex_to_see(utility_object.external_source.id),
            default: { template: 'See' },
            config: config
          )
        end

        def self.process_ski_resort(utility_object, raw_data, config, locale)
          if raw_data.dig('snow', 'itemSnow').present?
            raw_data['snow_report'] = []
            raw_data.dig('snow', 'itemSnow').each do |snow_item|
              raw_data['snow_report'] << transform_snow_report(utility_object, snow_item, config, locale)
            end
          end
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Bergfex::Transformations.bergfex_to_ski_resort(utility_object.external_source.id),
            default: { template: 'Skigebiet' },
            config: config
          )
        end

        def self.transform_snow_report(utility_object, raw_data, config, locale)
          DataCycleCore::Generic::Common::ImportFunctions.merge_default_values(
            config,
            DataCycleCore::Generic::Bergfex::Transformations
              .bergfex_to_ski_report(utility_object.external_source.id, locale)
              .call(raw_data)
          ).with_indifferent_access
        end

        def self.process_ski_resort_new(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Bergfex::Transformations.to_ski_resort_new(utility_object.external_source.id),
            default: { template: 'Skigebiet Bergfex' },
            config: config
          )
        end

        def self.process_snow_report_new(utility_object, raw_data, config, locale)
          raw_data.dig('snow', 'itemSnow').each do |snow_measure|
            snow_report = snow_measure
            snow_report['dateLastSnowfall'] = raw_data['dateLastSnowfall']
            snow_report['conditionSnow'] = raw_data['conditionSnow']
            snow_report['resort'] = raw_data['resort']
            snow_report['datetime'] = raw_data['datetime']
            snow_report['id'] = raw_data['id']

            DataCycleCore::Generic::Common::ImportFunctions.process_step(
              utility_object: utility_object,
              raw_data: snow_report,
              transformation: DataCycleCore::Generic::Bergfex::Transformations.to_snow_report_new(utility_object.external_source.id, locale),
              default: { template: 'Schneehöhe - Messpunkt Bergfex' },
              config: config
            )
          end
        end
      end
    end
  end
end
