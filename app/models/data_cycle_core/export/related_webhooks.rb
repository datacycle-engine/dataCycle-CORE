# frozen_string_literal: true

module DataCycleCore
  module Export
    # Re-exports the contents linking a content that changed. A receiver gets linked data embedded
    # in the payload of the content linking it, so a changed venue has to reach it as an update of
    # every exported event pointing at that venue — the venue itself is exported only when an
    # endpoint contains it (DataCycleCore::Export::Generic::Filter.filter_endpoints).
    class RelatedWebhooks
      ACTION = 'update'

      attr_reader :related, :content, :system_names, :invalidate

      # @param related [ActiveRecord::Relation] the contents linking the changed content
      # @param content [DataCycleCore::Thing, nil] the content that changed; nil once a destroy has
      #   cut the links, which invalidates the same set synchronously instead
      # @param system_names [Array<String>, nil] the receivers the changed content may reach
      #   (DataCycleCore::Webhook::Base.available_system_names); nil considers every enabled one
      # @param invalidate [Boolean] invalidate the caches of the contents this re-exports first; only
      #   a caller for whom nothing else invalidates them asks for it
      def initialize(related:, content: nil, system_names: nil, invalidate: false)
        @related = related
        @content = content
        @system_names = system_names
        @invalidate = invalidate
      end

      # @return [void]
      def call
        # first, and whether or not a re-export follows: the payload of a linking content is cached
        # under its own timestamps and the change moved none of them, so an update sent before the
        # invalidation ships the very payload it is meant to replace. The walk from the changed
        # content rather than the set re-exported: an embedded content between the two is nested in
        # that payload under a cache key of its own, and only that direction reaches it.
        content&.invalidate_related_cache if invalidate

        candidates_by_system = external_systems
          .index_with { |external_system| candidates(external_system) }
          .select { |_, relation| relation&.exists? }

        candidates_by_system.each do |external_system, relation|
          # not execute_update_webhooks: that one fans out again, from every content re-exported here
          relation.find_each do |linking_content|
            linking_content.execute_webhooks(ACTION, external_system_id: external_system.id)
          end
        end
      end

      private

      # The receivers the changed content may reach, intersected again with what this host has
      # enabled: +system_names+ was resolved when the job was enqueued. Whether a linking content
      # may reach one of them is decided per content when its webhooks are triggered.
      def external_systems
        names = Array.wrap(DataCycleCore.webhooks)
        names &= Array.wrap(system_names) if system_names.present?

        DataCycleCore::ExternalSystem
          .where(name: names)
          .to_a
          .select { |external_system| external_system.export_config&.key?(ACTION) }
      end

      # Narrowing to the endpoint's own contents up front is what keeps a hub content — a venue
      # linked by thousands of events — from enqueueing a webhook job per link only for the export
      # filter to discard it again. A relation rather than the ids: those of a hub are too many to
      # carry through Ruby and back into an IN list per batch. Systems filtering by something other
      # than endpoints keep the full set and are filtered per content as before.
      # @return [ActiveRecord::Relation, nil]
      def candidates(external_system)
        endpoints = DataCycleCore::Export::Generic::Filter.endpoints_for(external_system, external_system.export_filter_method_name(ACTION))

        # no endpoints configured at all is the case filter_endpoints never runs for; configured
        # endpoints that resolve to nothing is the case it rejects every content on
        return related if endpoints.nil?
        return if endpoints.blank?

        endpoints.map { |endpoint| related.where(id: DataCycleCore::Export::Generic::Filter.endpoint_things(endpoint).select(:id)) }.reduce(:or)
      end
    end
  end
end
