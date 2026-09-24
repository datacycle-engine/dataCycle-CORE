# frozen_string_literal: true

module DataCycleCore
  class UpdateComputedPropertiesJob < UniqueApplicationJob
    # Not cache_invalidation: SolidQueue claims ready work by strict priority
    # (SolidQueue::Execution.ordered), so priority 12 beside the invalidations' 5 is starved rather
    # than deferred for as long as that queue has work - 24,084 rows standing on production in 2026-09.
    queue_as :content_maintenance
    queue_with_priority 12
    limits_concurrency key: ->(*args) { args[0] }

    def perform(id, _changed_attributes)
      id_attribute_hash = Thing::PropertyDependency.id_attribute_hash(id)
      return if id_attribute_hash.blank?

      update_relevant_things(id_attribute_hash)
    end

    private

    def update_relevant_things(attribute_hash)
      queue = WorkerPool.new

      Thing.where(id: attribute_hash.keys).find_each do |t|
        queue.append do
          update_computed_properties(t, attribute_hash[t.id])
        end
      end

      queue.wait!
    end

    def update_computed_properties(content, keys)
      return if keys.blank?

      content.update_computed_values(keys:)
    end
  end
end
