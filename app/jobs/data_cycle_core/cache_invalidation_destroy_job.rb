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
        content.send(:execute_update_webhooks)
      end
    end

    def invalidate_things_cache
      return if arguments[3].blank?

      arguments[3].each do |thing_id|
        DataCycleCore::CacheInvalidationJob.perform_later('DataCycleCore::Thing', thing_id, 'invalidate_self_and_update_search')
      end
    end
  end
end
