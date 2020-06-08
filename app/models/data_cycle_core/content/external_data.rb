# frozen_string_literal: true

module DataCycleCore
  module Content
    module ExternalData
      def add_external_system_data(external_system, data = nil, status = nil)
        external_data = external_system_syncs.find_or_initialize_by(external_system_id: external_system.id)
        external_data.update({ data: data, status: status }.compact)
      end

      def remove_external_system_data(external_system)
        external_data = external_system_syncs.find_by(external_system_id: external_system.id)
        external_data.update(data: nil)
      end

      def external_system_sync_by_system(external_system)
        external_system_syncs.find_or_create_by(external_system_id: external_system.id)
      end

      def external_system_data(external_system)
        external_system_syncs.find_by(external_system_id: external_system.id)&.data
      end

      def external_source_to_external_system_syncs
        return if external_source_id.nil?

        external_sync = external_system_syncs.where(external_system_id: external_source_id).first_or_initialize

        external_sync.data ||= {}
        external_sync.data = external_sync.data.merge({ 'external_key' => external_key })
        external_sync.save

        update_columns(external_key: nil, external_source_id: nil) # rubocop:disable Rails/SkipsModelValidations
      end
    end
  end
end
