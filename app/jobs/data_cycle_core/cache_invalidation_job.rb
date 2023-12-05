# frozen_string_literal: true

module DataCycleCore
  class CacheInvalidationJob < UniqueApplicationJob
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

    def perform(class_name, id, method_name)
      class_name.classify.constantize.find_by(id:)&.send(method_name)
    end
  end
end
