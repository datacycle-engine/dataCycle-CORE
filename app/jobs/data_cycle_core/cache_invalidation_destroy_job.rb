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
      "#{arguments[0].underscore_blanks}_#{arguments[2]}"
    end

    def perform(_class_name, _id, method_name, _things_ids)
      send(method_name)
    end

    private

    def execute_things_webhooks_destroy
      return if arguments[3].blank?

      DataCycleCore::Thing.where(id: arguments[3]).find_each do |content|
        content.send(:execute_update_webhooks) unless content.embedded?
      end
    end

    def invalidate_things_cache
      return if arguments[3].blank?

      things = DataCycleCore::Thing.where(id: arguments[3])

      things.invalidate_all
      things.update_search_all
    end
  end
end
