# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gip
      module Processing
        def self.process_section(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Gip::Transformations.to_section(utility_object.external_source.id),
            default: { template: 'Route' },
            config: config
          )
        end

        def self.process_route(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Gip::Transformations.to_route(utility_object.options.dig('import', 'external_id_prefix')),
            default: { template: 'Gesamtroute' },
            config: config
          )
        end

        def self.process_route_feature(utility_object, raw_data, config)
          DataCycleCore::Generic::Common::ImportFunctions.process_step(
            utility_object: utility_object,
            raw_data: raw_data,
            transformation: DataCycleCore::Generic::Gip::Transformations.to_route_feature(utility_object.external_source.id),
            default: { template: 'Gesamtroute' },
            config: config
          )
        end
      end
    end
  end
end
