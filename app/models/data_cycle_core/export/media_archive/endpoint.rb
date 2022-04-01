# frozen_string_literal: true

module DataCycleCore
  module Export
    module MediaArchive
      class Endpoint < DataCycleCore::Export::Generic::Endpoint
        def path_transformation(data, external_system, path_type, type = 'media', path = nil)
          id = data&.external_system_syncs&.where(external_system_id: external_system.id)&.pluck(:external_key)&.first ||
               (data&.external_source_id == external_system.id && data&.external_key) ||
               data&.id

          id.gsub!(/MedienArchive - CopyrightHolder - |MedienArchive - Person - |MedienArchive - Photographer - /, '')
          id.squish!

          format(path.presence || external_system.config.dig('export_config', path_type.to_s, 'path') || external_system.config.dig('export_config', 'path') || path_type.to_s, id: id, type: type)
        end
      end
    end
  end
end
