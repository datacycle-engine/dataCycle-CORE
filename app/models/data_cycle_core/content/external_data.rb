# frozen_string_literal: true

module DataCycleCore
  module Content
    module ExternalData
      def add_external_system_data(external_system, data = nil, status = nil, sync_type = 'export', external_key = nil)
        external_data = external_system_syncs.find_or_initialize_by(external_system_id: external_system.id, sync_type: sync_type, external_key: external_key)
        external_data.attributes = { data: data, status: status }.compact
        external_data.save
      end

      def remove_external_system_data(external_system, sync_type = 'export', external_key = nil)
        external_data = external_system_syncs.find_by(external_system_id: external_system.id, sync_type: sync_type, external_key: external_key)
        external_data.update(data: nil)
      end

      def external_system_sync_by_system(external_system, sync_type = 'export', external_key = nil)
        external_system_syncs.find_or_create_by(external_system_id: external_system.id, sync_type: sync_type, external_key: external_key)
      end

      def external_system_data_all(external_system, sync_type = 'export', external_key = nil)
        external_system_syncs.find_by(external_system_id: external_system.id, sync_type: sync_type, external_key: external_key)
      end

      def external_system_data(external_system, sync_type = 'export', external_key = nil)
        external_system_data_all(external_system, sync_type, external_key)&.data
      end

      def external_source_to_external_system_syncs
        return if external_source_id.nil? || external_key.nil?

        external_system_syncs.where(external_system_id: external_source_id, sync_type: 'import', external_key: external_key).first_or_create

        update_columns(external_key: nil, external_source_id: nil)
      end
    end
  end
end
