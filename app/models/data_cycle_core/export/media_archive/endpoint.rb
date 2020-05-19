# frozen_string_literal: true

module DataCycleCore
  module Export
    module MediaArchive
      class Endpoint < DataCycleCore::Export::Generic::Endpoint
        def path_transformation(data, external_system, path_type)
          id = data&.external_source&.name&.include?('Medienarchiv') && data&.external_key.present? ? data&.external_key : data&.id
          format(external_system.config.dig('export_config', path_type.to_s, 'path') || external_system.config.dig('export_config', 'path') || path_type.to_s, id: id)
        end
      end
    end
  end
end
