# frozen_string_literal: true

module DataCycleCore
  class UpdateComputedPropertiesJob < UniqueApplicationJob
    PRIORITY = 12
    WEBHOOK_PRIORITY = 6

    queue_as :cache_invalidation

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

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

      content.webhook_priority = WEBHOOK_PRIORITY
      content.update_computed_values(keys:)
    end
  end
end
