# frozen_string_literal: true

module DataCycleCore
  class ClassificationMappingJob < ApplicationJob
    PRIORITY = 10

    queue_as :cache_invalidation

    before_enqueue :notify_with_lock

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def delayed_reference_type
      'data_cycle_core_classification_alias_update_mappings'
    end

    def perform(id, classification_ids)
      ca = DataCycleCore::ClassificationAlias.find_by(id: id)

      return if ca.nil?

      to_insert = classification_ids - ca.classification_ids
      to_delete = ca.classification_ids - classification_ids

      if to_insert.present?
        ca.classification_groups.insert_all(to_insert.map { |cid| { classification_id: cid } }, unique_by: :classification_groups_ca_id_c_id_uq_idx, returning: false)

        DataCycleCore::Classification.where(id: to_insert).find_each do |c|
          ca.send(:classifications_added, c)
        end
      end

      if to_delete.present?
        ca.classification_groups.where(classification_id: to_delete).delete_all

        DataCycleCore::Classification.where(id: to_delete).find_each do |c|
          ca.send(:classifications_removed, c)
        end
      end

      if to_insert.present? || to_delete.present? ? ca.update(updated_at: Time.zone.now) : true
        ActionCable.server.broadcast('classification_update', { type: 'unlock', id: id })
      else
        ActionCable.server.broadcast('classification_update', { type: 'error', id: id })
      end
    end

    private

    def notify_with_lock
      ActionCable.server.broadcast('classification_update', { type: 'lock', id: arguments[0] })
    end
  end
end
