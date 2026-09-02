# frozen_string_literal: true

module DataCycleCore
  class CacheInvalidationJob < UniqueApplicationJob
    queue_as :cache_invalidation
    queue_with_priority 10
    limits_concurrency key: ->(*args) { "#{args[2]}/#{args[1]}" }

    def perform(class_name, id, method_name)
      class_name.classify.constantize.find(id).send(method_name)
    end
  end
end
