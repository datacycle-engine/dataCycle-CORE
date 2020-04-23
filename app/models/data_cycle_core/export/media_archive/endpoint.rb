# frozen_string_literal: true

module DataCycleCore
  module Export
    module MediaArchive
      class Endpoint < DataCycleCore::Export::Generic::Endpoint
        def path_transformation(data, external_system, path_type)
          id = data&.external_source&.name&.inlucde?('Medienarchiv') && data&.external_key.present? ? data&.external_key : data&.id
          format(external_system.config.dig('push_config', path_type.to_s, 'path') || external_system.config.dig('push_config', 'path') || path_type.to_s, id: id)
        end
      end
    end
  end
end
