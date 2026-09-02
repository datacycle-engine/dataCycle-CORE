# frozen_string_literal: true

module DataCycleCore
  module Export
    # Removes external_system_sync links after content has been deleted from an
    # external system (e.g. the DZT Knowledge Graph), so stale connection badges
    # are no longer shown. Cleans up the content itself and its orphaned linked
    # children, keeping a child only if another still-exported content references
    # it. Writes a history entry for every content whose sync is removed.
    class SyncCleanup
      THING_TYPE = 'DataCycleCore::Thing'
      EXPORT = 'export'
      DUPLICATE = 'duplicate'

      attr_reader :content, :external_system, :include_self

      def initialize(content:, external_system:, include_self: true)
        @content = content
        @external_system = external_system
        @include_self = include_self
      end

      # removes the matching external_system_sync links (content and/or its orphaned children) in a transaction
      def call
        return unless content.is_a?(DataCycleCore::Thing) && external_system.is_a?(DataCycleCore::ExternalSystem)

        ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
          remove_self_syncs if include_self
          remove_orphaned_linked_syncs
        end
      end

      private

      def remove_self_syncs
        syncs = content.external_system_syncs.where(external_system_id: external_system.id, sync_type: [EXPORT, DUPLICATE])
        remove_syncs(content, syncs)
      end

      # candidate children: linked (recursive, non-embedded) contents with an 'export' sync to this system
      def remove_orphaned_linked_syncs
        candidate_ids = export_syncs_for(content.linked_contents.where.not(id: content.id).select(:id)).distinct.pluck(:syncable_id)

        DataCycleCore::Thing.where(id: candidate_ids).find_each do |child|
          next if still_exported_elsewhere?(child)

          remove_syncs(child, export_syncs_for(child.id))
        end
      end

      # keep the child if another content that references it still has an active 'export' sync to this system
      def still_exported_elsewhere?(child)
        export_syncs_for(child.depending_contents.where.not(id: [content.id, child.id]).select(:id)).exists?
      end

      def export_syncs_for(syncable_ids)
        DataCycleCore::ExternalSystemSync.where(external_system_id: external_system.id, sync_type: EXPORT, syncable_type: THING_TYPE, syncable_id: syncable_ids)
      end

      # writes a history snapshot once and deletes the matching sync rows (no-op when none exist → idempotent on retry)
      def remove_syncs(item, syncs)
        return unless syncs.exists?

        item.to_history(delete: false)
        syncs.delete_all
      end
    end
  end
end
