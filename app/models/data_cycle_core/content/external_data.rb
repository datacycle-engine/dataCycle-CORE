# frozen_string_literal: true

module DataCycleCore
  module Content
    module ExternalData
      def add_external_system_data(external_system, data = nil, status = nil, sync_type = 'export', external_key = nil, use_key = true)
        external_data =
          if use_key
            external_system_syncs.find_or_initialize_by(external_system_id: external_system.id, sync_type:, external_key: external_key.presence)
          else
            external_system_syncs.find_or_initialize_by(external_system_id: external_system.id, sync_type:)
          end
        external_data.attributes = { data:, status:, external_key: external_key.presence }.compact
        external_data.save
        external_data
      rescue ActiveRecord::RecordNotUnique
        retry
      end

      def remove_external_system_data(external_system, sync_type = 'export', external_key = nil)
        external_data = external_system_syncs.find_by(external_system_id: external_system.id, sync_type:, external_key:)
        external_data.update(data: nil)
      end

      def external_system_sync_by_system(external_system:, sync_type: 'export', external_key: nil, use_key: false)
        find_by_hash = { external_system_id: external_system.id, sync_type: }
        find_by_hash[:external_key] = external_key if use_key && external_key.present?

        external_system_syncs.find_or_create_by(**find_by_hash) do |s|
          s.external_key = external_key
        end
      rescue ActiveRecord::RecordNotUnique
        nil
      end

      def external_system_data_all(external_system, sync_type = 'export', external_key = nil, use_key = true)
        if use_key
          external_system_syncs.find_by(external_system_id: external_system.id, sync_type:, external_key: external_key.presence)
        else
          external_system_syncs.find_by(external_system_id: external_system.id, sync_type:)
        end
      end

      def external_system_data(external_system, sync_type = 'export', external_key = nil, use_key = true)
        external_system_data_all(external_system, sync_type, external_key.presence, use_key)&.data
      end

      def external_system_data_with_key(external_system, sync_type = 'export', external_key = nil)
        external_system_syncs.find_by(external_system_id: external_system.id, sync_type:, external_key:)&.data
      end

      def external_source_to_external_system_syncs(sync_type = 'import')
        return if external_source_id.nil?

        begin
          external_system_syncs.where(external_system_id: external_source_id, sync_type:, external_key: external_key || id).first_or_create do |sync|
            sync.status = 'success'
          end
        rescue ActiveRecord::RecordNotUnique
          nil
        end

        update_columns(external_key: nil, external_source_id: nil)
      end

      def view_all_external_data
        all_data = []

        if external_source_id.present? && external_key.present?
          all_data.push({
            external_system_id: external_source_id,
            external_identifier: external_source.identifier,
            external_key:
          }.with_indifferent_access)
        end

        all_data.concat(external_system_syncs.to_external_data_hash)
      end

      def external_keys_by_system_id(external_system_id)
        return [] if external_system_id.blank?

        [
          (external_key if external_source_id == external_system_id),
          external_system_syncs.where(external_system_id:).pluck(:external_key)
        ].flatten.compact
      end

      def switch_primary_external_system(external_system_sync)
        transaction(joinable: false, requires_new: true) do
          add_external_system_data(external_source, { external_key: }, 'success', 'duplicate', external_key) if external_source_id.present? && external_key.present?

          if external_system_sync.external_key.present? && external_system_sync.external_system_id.present?
            update_columns(external_source_id: external_system_sync.external_system_id, external_key: external_system_sync.external_key)

            external_system_sync.destroy
          end
        end
      end

      def change_primary_system(new_external_system, new_external_key)
        external_system_syncs.detect { |s|
          s.external_system_id == new_external_system.id &&
            s.external_key == new_external_key
        }&.mark_for_destruction

        if external_system_syncs.none? do |s|
          s.external_system_id == external_source_id &&
          s.external_key == external_key &&
          s.sync_type == 'duplicate'
        end
          external_system_syncs.build(
            external_system_id: external_source_id,
            external_key: external_key,
            sync_type: 'duplicate',
            status: 'success'
          )
        end

        self.external_key = new_external_key
        self.external_source_id = new_external_system.id
      end
    end
  end
end
