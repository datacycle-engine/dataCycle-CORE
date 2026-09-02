# frozen_string_literal: true

module DataCycleCore
  module Content
    # Triggers the re-export of the contents linking this one, for the reason
    # DataCycleCore::Export::RelatedWebhooks documents.
    module RelatedWebhooks
      extend ActiveSupport::Concern

      included do
        after_destroy_commit :add_destroy_related_webhooks_job, if: :prepared_destroy_related_ids?
      end

      # The fan-out every bulk caller shares. A module function rather than a scope-style class
      # method, which ActiveRecord surrounds with current_scope when it is called on a relation:
      # that scope would still be set while #execute_update_webhooks runs, and wherever the webhook
      # runs inline (synchronous_webhooks, queue: 'inline') it would narrow the Thing lookups behind
      # it to this set — DataCycleCore::WebhookJob#parse_data_item and
      # DataCycleCore::Export::Generic::Filter.endpoint_things.
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

        # embedded dropped in SQL: #execute_update_webhooks is a no-op for them anyway — one reaches
        # a receiver inside the payload of the content embedding it
        scope.without_embedded.find_each(&:execute_update_webhooks)
      end

      # The receivers this change may reach at all, resolved by the same rule as its own webhooks: an
      # import would otherwise come back to the system it came from as an update of every content
      # linking what it imported. Whether a linking content may reach one of them is decided per
      # content, by that rule applied to it.
      def add_related_webhooks_job(related_ids = nil, invalidate: false)
        # available_system_names subtracts prevent_webhooks by name; the boolean form suppresses all
        return if prevent_webhooks.is_a?(TrueClass) || embedded?

        system_names = DataCycleCore::Webhook::Base.available_system_names(self)

        return if system_names.blank?

        DataCycleCore::RelatedWebhooksJob.perform_later(id, related_ids, system_names, invalidate)
      end

      # The set #invalidate_related_cache reaches, minus what a receiver never holds by itself: an
      # embedded content reaches it inside the payload of the one embedding it. Deliberately the
      # same walk rather than an equivalent one — a content the invalidation does not reach keeps
      # the cache key its payload is stored under, so re-exporting it would ship what it already has.
      # @return [ActiveRecord::Relation]
      def related_webhook_contents
        self.class.base_class
          .without_embedded
          .where(id: with_cached_related_contents.where.not(id:).select(:id))
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
