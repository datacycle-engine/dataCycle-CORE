# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      module Processing
        def self.process_slope(utility_object, raw_data, config)
          ski_region_data = raw_data.dig('co', 'pl', 'pcs', 'pc').detect { |i| i.dig('t') == '4' }.dig('pcc')
          ski_region_id = ski_region_data.dig('rid').downcase
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
          ski_region_data = raw_data.dig('co', 'pl', 'pcs', 'pc').detect { |i| i.dig('t') == '4' }.dig('pcc')
          ski_region_id = ski_region_data.dig('rid').downcase
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
          ski_region_data = raw_data.dig('co', 'pl', 'pcs', 'pc').detect { |i| i.dig('t') == '4' }.dig('pcc')
          ski_region_id = ski_region_data.dig('rid').downcase
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
          ski_region_data = raw_data.dig('co', 'pl', 'pcs', 'pc').detect { |i| i.dig('t') == '4' }.dig('pcc').except('pccd')
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: ski_region_data,
            transformation: DataCycleCore::Generic::FeratelWebcam::Transformations.to_ski_region(utility_object.external_source.id),
            default: { template: 'Skigebiet' },
            config: config
          )
        end
      end
    end
  end
end
