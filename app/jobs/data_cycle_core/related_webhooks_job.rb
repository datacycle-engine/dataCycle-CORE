# frozen_string_literal: true

module DataCycleCore
  # Triggers the update webhooks of the contents linking a content that changed. Resolving the links
  # off the request is what makes this affordable for a content thousands of others link to.
  class RelatedWebhooksJob < UniqueApplicationJob
    # whichever work this job is doing: carrying an invalidation it is the only one its set gets, so
    # it has to run where DataCycleCore::CacheInvalidationJob would have — a host that leaves the
    # webhook queue without a worker, as test/dummy/config/queue.yml deliberately does, would lose it
    # along with the export. Carrying none it is export fan-out and nothing else, and belongs behind
    # the queue of the deliveries it enqueues.
    queue_as { arguments[3] ? :cache_invalidation : :webhooks }
    # level with DataCycleCore::CacheInvalidationJob on its queue, behind DataCycleCore::WebhookJob on
    # the other: a bulk update enqueues one of these per content and none may delay a delivery
    queue_with_priority 10
    # args[2] is part of it so that a queued job for a narrower set of receivers cannot swallow an
    # enqueue meant for more of them, and args[3] so that one queued without an invalidation to
    # carry cannot swallow an enqueue that carries one, whose caller invalidates nowhere else
    limits_concurrency key: ->(*args) { "#{args[0]}/#{args[1].nil? ? 'linked' : 'destroyed'}/#{Array.wrap(args[2]).sort.join(',')}/#{args[3] ? 'invalidating' : 'sending'}" }

    # invalidate stays positional: ActiveJob serializes keywords into a trailing hash, which the
    # queue and the concurrency key above would both have to dig through to read it
    #
    # @param id [String] id of the content that changed
    # @param related_ids [Array<String>, nil] linking contents captured before a destroy cut the
    #   links; resolved here for every other change
    # @param system_names [Array<String>, nil] the receivers the changed content may reach
    # @param invalidate [Boolean] whether this job carries the caller's cache invalidation
    def perform(id, related_ids = nil, system_names = nil, invalidate = false) # rubocop:disable Style/OptionalBooleanParameter
      # nil on a destroy, and nothing left to invalidate from: before_destroy_data_hash invalidated
      # the same set synchronously, while the links were still there to walk
      content = DataCycleCore::Thing.find_by(id:) if related_ids.nil?
      related = related_ids.nil? ? content&.related_webhook_contents : DataCycleCore::Thing.where(id: related_ids)

      return if related.nil?

      DataCycleCore::Export::RelatedWebhooks.new(related:, content:, system_names:, invalidate:).call
    end
  end
end
