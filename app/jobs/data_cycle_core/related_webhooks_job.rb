# frozen_string_literal: true

module DataCycleCore
  # Triggers the update webhooks of the contents linking the ones that changed. Resolving the links
  # off the request is what makes this affordable for a content thousands of others link to.
  class RelatedWebhooksJob < UniqueApplicationJob
    # Never the webhooks queue the deliveries it enqueues land on. Carrying an invalidation it is the
    # only one its set gets, so it has to run where DataCycleCore::CacheInvalidationJob would have,
    # and test/dummy/config/queue.yml deliberately leaves webhooks without a worker. Carrying none it
    # resolves links and enqueues without ever talking to a receiver, so it has no business holding
    # one of the three threads that queue keeps for HTTP pushes.
    queue_as :cache_invalidation
    # 5 carrying an invalidation: the job stands in for the DataCycleCore::CacheInvalidationJob the
    # save stood down, and until it runs the contents it re-exports hold the caches that invalidation
    # is there to lift. 10 carrying none: .fan_out invalidated its whole set before it enqueued, so
    # the job replaces nothing and has no claim on the queue ahead of the invalidations a save waits
    # on — it sits level with DataCycleCore::CacheInvalidationJob instead.
    queue_with_priority { arguments[3] ? 5 : 10 }
    # args[2] is part of it so that a queued job for a narrower set of receivers cannot swallow an
    # enqueue meant for more of them, and args[3] so that one queued without an invalidation to
    # carry cannot swallow an enqueue that carries one, whose caller invalidates nowhere else
    #
    # args[0] is a list once .fan_out coalesces a batch, hashed for the reason
    # DataCycleCore::CacheInvalidationDestroyJob documents: solid_queue_jobs.concurrency_key is
    # btree-indexed and rejects an index row over 2704 bytes, roughly 72 UUIDs. Sorted before hashing
    # so the key identifies the set, not the order find_in_batches yielded it in.
    limits_concurrency key: ->(*args) { "#{Digest::SHA256.hexdigest(Array.wrap(args[0]).sort.join(','))}/#{args[1].nil? ? 'linked' : 'destroyed'}/#{Array.wrap(args[2]).sort.join(',')}/#{args[3] ? 'invalidating' : 'sending'}" }

    # invalidate stays positional: ActiveJob serializes keywords into a trailing hash, which the
    # concurrency key and the priority above would both have to dig through to read it
    #
    # @param ids [String, Array<String>] id(s) of the contents that changed; a list once .fan_out has
    #   coalesced a batch of them, whose linking contents are then resolved in one walk
    # @param related_ids [Array<String>, nil] linking contents captured before a destroy cut the
    #   links; resolved here for every other change
    # @param system_names [Array<String>, nil] the receivers the changed contents may reach
    # @param invalidate [Boolean] whether this job carries the caller's cache invalidation
    def perform(ids, related_ids = nil, system_names = nil, invalidate = false) # rubocop:disable Style/OptionalBooleanParameter
      # left nil on a destroy: the rows are gone, which is why that caller resolved related_ids
      # while the links were still there to walk
      sources = DataCycleCore::Thing.where(id: ids) if related_ids.nil?
      related = related_ids.nil? ? DataCycleCore::Content::RelatedWebhooks.linking_contents(sources) : DataCycleCore::Thing.where(id: related_ids)

      # Not skipped when +related+ is empty - the invalidation also covers the embedded linkers
      # .linking_contents drops, so a content linked only by those still has an invalidation to
      # run, and this job is the only one that will, the save having stood
      # DataCycleCore::CacheInvalidationJob down.
      DataCycleCore::Export::RelatedWebhooks.new(related:, sources: (sources if invalidate), system_names:, invalidate:).call
    end
  end
end
