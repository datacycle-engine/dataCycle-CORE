# frozen_string_literal: true

module DataCycleCore
  class CacheInvalidationDestroyJob < UniqueApplicationJob
    PRIORITY = 10

    queue_as :cache_invalidation

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[1].to_s
    end

    def delayed_reference_type
      "#{arguments[0]}##{arguments[2]}"
    end

    def perform(_class_name, _id, method_name, things_ids)
      send(method_name, things_ids)
    end

    private

    def execute_things_webhooks_destroy(things_ids)
      return if things_ids.blank?

      DataCycleCore::Thing.where(id: things_ids).find_each do |content|
        content.send(:execute_update_webhooks) unless content.embedded?
      end
    end

    def update_things_search(things_ids)
      return if things_ids.blank?

      DataCycleCore::Thing.where(id: things_ids).update_search_all
    end
  end
end
