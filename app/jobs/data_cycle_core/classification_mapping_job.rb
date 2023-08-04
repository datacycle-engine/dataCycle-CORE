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
      classification_alias = DataCycleCore::ClassificationAlias.find_by(id:)

      return if classification_alias.nil?

      classification_alias.classification_ids = classification_ids
      if classification_alias.save
        ActionCable.server.broadcast('classification_update', { type: 'unlock', id: })
      else
        ActionCable.server.broadcast('classification_update', { type: 'error', id: })
      end
    end

    private

    def notify_with_lock
      ActionCable.server.broadcast('classification_update', { type: 'lock', id: arguments[0] })
    end
  end
end
