# frozen_string_literal: true

module DataCycleCore
  module Content
    # Triggers the re-export of the contents linking the ones that changed, a content at a time or
    # coalesced into a batch, for the reason DataCycleCore::Export::RelatedWebhooks documents.
    module RelatedWebhooks
      extend ActiveSupport::Concern

      # How many changed contents share one fan-out job. A batch is resolved in one walk, so a content
      # linking several of its members is re-exported once for the batch rather than once per member:
      # an event linking 500 contents of one batch drops from 500 deliveries to 1, and one whose links
      # spread over several batches to one delivery per batch — which is what a larger size buys.
      # Level with ConceptScheme::CCC_REFRESH_BATCH_SIZE; .with_cached_related_contents
      # inlines the ids into a recursive CTE, some 40KB of statement at this size.
      FAN_OUT_BATCH_SIZE = 1_000

      included do
        after_destroy_commit :add_destroy_related_webhooks_job, if: :prepared_destroy_related_ids?
      end

      # The union of what links the given contents, minus those contents themselves: each is
      # re-exported in its own right by whoever changed it, so one linking another needs no delivery
      # from the fan-out on top of the one it already gets. Embedded contents drop out — a receiver
      # holds one inside the payload of the content embedding it.
      #
      # Deliberately the same walk as .with_cached_related_contents rather than an equivalent one: a
      # content the invalidation does not reach keeps the cache key its payload is stored under, so
      # re-exporting it would ship what it already has.
      #
      # A module function for the reason .fan_out is one — as a class method on Thing, ActiveRecord
      # would wrap the body in current_scope and the opening .without_embedded would come back
      # narrowed to the very ids the walk then excludes, an empty relation for every caller.
      # @param scope [ActiveRecord::Relation] the contents that changed
      # @return [ActiveRecord::Relation]
      def self.linking_contents(scope)
        model = scope.model.base_class
        ids = scope.pluck(:id)

        model
          .without_embedded
          .where(id: model.where(id: ids).with_cached_related_contents.where.not(id: ids).select(:id))
      end

      # The fan-out every bulk caller shares. A module function rather than a scope-style class
      # method, which ActiveRecord surrounds with current_scope when it is called on a relation:
      # that scope would still be set while the webhooks below run, and wherever one runs inline
      # (synchronous_webhooks, queue: 'inline') it would narrow the Thing lookups behind it to this
      # set — DataCycleCore::WebhookJob#parse_data_item and
      # DataCycleCore::Export::Generic::Filter.endpoint_things.
      #
      # #execute_update_webhooks is not used per content here, though it is what pairs a content's own
      # delivery with its fan-out everywhere else: it fans out from one content, so an event linking
      # 500 members of this scope would be re-exported 500 times. Leaving those 500 to
      # DataCycleCore::WebhookJob's concurrency key works only while they are all still queued, and
      # this is the one caller holding a set, so it resolves them together instead.
      #
      # @param scope [ActiveRecord::Relation] the contents to re-export
      # @param invalidate_related_cache [Boolean] invalidate what the fan-out re-exports first, in
      #   one statement over the whole set; asking each content for it would repeat the walk per
      #   record. False for a caller that invalidates the same set itself.
      # @return [void]
      def self.fan_out(scope, invalidate_related_cache: false)
        # the walk starts at the whole set, embedded contents included: what links one of those is
        # the content embedding it, whose payload nests it under a cache key of its own
        scope.with_cached_related_contents.invalidate_all if invalidate_related_cache

        # embedded dropped in SQL: a fan-out is a no-op for them anyway — one reaches a receiver
        # inside the payload of the content embedding it
        scope.without_embedded.find_in_batches(batch_size: FAN_OUT_BATCH_SIZE) do |contents|
          contents.each { |content| content.execute_webhooks(:update) }

          enqueue_batch(contents)
        end
      end

      # One fan-out per distinct receiver set: whether a change may reach a receiver at all is a
      # property of the content that changed, so contents disagreeing about it cannot share a job.
      # @param contents [Array<DataCycleCore::Thing>] one batch of changed contents
      # @return [void]
      def self.enqueue_batch(contents)
        contents
          .reject(&:all_webhooks_prevented?)
          .select(&:cached_related_contents?)
          .group_by { |content| DataCycleCore::Webhook::Base.available_system_names(content).sort }
          .each { |system_names, group| enqueue(group.map(&:id), system_names) }
      end

      # @param ids [String, Array<String>] the content(s) that changed
      # @param system_names [Array<String>] the receivers they may reach; sorted so both callers
      #   enqueue one receiver set as one argument list, whatever order DataCycleCore.webhooks gave
      # @param invalidate [Boolean] whether the job carries the caller's cache invalidation: the
      #   walk starts from every id in one statement, the way .fan_out invalidates its set up front
      # @return [DataCycleCore::RelatedWebhooksJob, false, nil] false when abort_if_queued dropped it
      def self.enqueue(ids, system_names, related_ids: nil, invalidate: false)
        return if system_names.blank?

        DataCycleCore::RelatedWebhooksJob.perform_later(ids, related_ids, system_names.sort, invalidate)
      end

      # The receivers this change may reach at all, resolved by the same rule as its own webhooks: an
      # import would otherwise come back to the system it came from as an update of every content
      # linking what it imported. Whether a linking content may reach one of them is decided per
      # content, by that rule applied to it.
      #
      # @param shared_embedded_ids [Array<String>] embedded this save changed that other contents
      #   embed too (Feature::ReusableEmbedded); they join the walk so those parents are re-exported
      def add_related_webhooks_job(related_ids = nil, invalidate: false, shared_embedded_ids: [])
        return if all_webhooks_prevented? || embedded?

        ids = shared_embedded_ids.any? ? [id, *shared_embedded_ids] : id

        DataCycleCore::Content::RelatedWebhooks.enqueue(
          ids, DataCycleCore::Webhook::Base.available_system_names(self), related_ids:, invalidate:
        )
      end

      # Webhook::Base.available_system_names subtracts the receivers prevent_webhooks names. The
      # boolean form names none and suppresses every one instead, so it has to be read separately —
      # .enqueue_batch and #add_related_webhooks_job both stand down on it.
      # @return [Boolean]
      def all_webhooks_prevented?
        prevent_webhooks.is_a?(TrueClass)
      end

      # @see .linking_contents
      # @return [ActiveRecord::Relation]
      def related_webhook_contents
        DataCycleCore::Content::RelatedWebhooks.linking_contents(self.class.base_class.where(id:))
      end

      # Resolves the linking contents while the links still exist; the job cannot do it itself once
      # the destroy has cut them.
      # @return [Array<String>]
      def prepare_destroy_related_webhooks_job
        @destroy_related_ids = related_webhook_contents.ids
      end

      # @return [Boolean]
      def prepared_destroy_related_ids?
        @destroy_related_ids.present?
      end

      # @return [void]
      def add_destroy_related_webhooks_job
        add_related_webhooks_job(@destroy_related_ids)
      end
    end
  end
end
