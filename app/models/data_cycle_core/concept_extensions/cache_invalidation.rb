# frozen_string_literal: true

module DataCycleCore
  module ConceptExtensions
    # Everything a concept change owes the contents that carry it: the api cache, the search index,
    # the computed properties derived from it, and the webhooks.
    #
    # All of it is enqueued, never run inline - a single concept can reach six figures of contents.
    module CacheInvalidation
      extend ActiveSupport::Concern

      included do
        after_update :add_things_cache_invalidation_job, if: :cached_attributes_changed?
        after_update :add_things_search_update_job, if: :search_attributes_changed?
        after_update :add_linked_things_computed_properties_job, if: :search_attributes_changed?
        after_update :add_things_webhooks_job_update, if: :webhook_attributes_changed?
        before_destroy :add_things_job_destroy, :add_things_webhooks_job_destroy
        after_destroy :clean_stored_filters
      end

      # The contents this concept reaches: assigned directly, through a mapping, or through a
      # descendant. Reads the materialised collected_concept_contents rather than walking the paths.
      def linked_contents
        DataCycleCore::Thing.where(
          collected_concept_contents
            .without_hidden # #47172: hidden mappings do not link a content to this concept
            .select(1)
            .where('collected_concept_contents.thing_id = things.id')
            .arel
            .exists
        )
      end

      # The contents this concept stands for directly: its own, plus the ones its mappings' targets
      # classify - a `related` link makes this concept classify the target's contents too. Narrower
      # than #linked_contents, which also covers what a descendant classifies.
      def assigned_things
        mapped_ids = DataCycleCore::ConceptLink.related.where(parent_id: id).select(:child_id)

        DataCycleCore::Thing.where(
          id: DataCycleCore::ConceptContent
            .where(concept_id: id)
            .or(DataCycleCore::ConceptContent.where(concept_id: mapped_ids))
            .select(:content_data_id)
        )
      end

      # Bulk sibling of the mapped_concepts_added/mapped_concepts_removed association callbacks for a
      # mapping delta that touches many concepts at once. Computes the union of affected contents in
      # one query and enqueues ONE job per side effect (search, webhooks, computed-property
      # recompute), sidestepping the per-concept dedup collapse and N+1 churn described there.
      def mapped_concepts_changed(concept_ids)
        return if concept_ids.blank?

        @mapped_concepts_changed = true

        thing_ids = DataCycleCore::Thing.joins(:concept_contents).where(concept_contents: { concept_id: concept_ids }).distinct.pluck(:id)
        enqueue_thing_cache_jobs(thing_ids)
        add_things_computed_properties_job(thing_ids)
      end

      private

      # after_add/after_remove association callbacks - fire once per mapped concept. For a bulk
      # mapping delta (ClassificationMappingJob / the dc:classifications rake) call
      # #mapped_concepts_changed instead: looping these would run a pluck + enqueue per concept and,
      # because CacheInvalidationDestroyJob dedups on (concept, method) without thing_ids, collapse
      # every side effect down to the last concept's contents.
      def mapped_concepts_added(concept = nil)
        enqueue_thing_cache_jobs(concept&.things&.pluck(:id))
        @mapped_concepts_changed = true
      end

      def mapped_concepts_removed(concept = nil)
        enqueue_thing_cache_jobs(concept&.things&.pluck(:id))
        @mapped_concepts_changed = true
      end

      def search_attributes_changed?
        return @search_attributes_changed if defined? @search_attributes_changed

        @search_attributes_changed = saved_changes.key?('internal_name') ||
                                     saved_changes['name_i18n']&.map(&:compact_blank)&.reject(&:blank?).present?
      end

      def cached_attributes_changed?
        webhook_attributes_changed? || @mapped_concepts_changed || saved_changes['ui_configs']&.map { |attr| attr&.reject { |_k, v| v.blank? } }&.reject(&:blank?).present?
      end

      def webhook_attributes_changed?
        return @webhook_attributes_changed if defined? @webhook_attributes_changed

        @webhook_attributes_changed = saved_changes.keys.intersect?(['internal_name', 'uri']) ||
                                      saved_changes['name_i18n']&.map(&:compact_blank)&.reject(&:blank?).present? ||
                                      saved_changes['description_i18n']&.map(&:compact_blank)&.reject(&:blank?).present?
      end

      # Enqueues a single recompute for the union of affected contents. Separate from
      # enqueue_thing_cache_jobs because the per-concept callbacks intentionally skip the (expensive)
      # recompute - it runs once for the whole delta via #mapped_concepts_changed.
      def add_things_computed_properties_job(thing_ids)
        return if thing_ids.blank?

        DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'update_things_computed_properties', thing_ids)
      end

      # A rename or a move writes no content, so nothing else recomputes a value derived from this concept.
      # The stale contents are linked_contents, not the directly assigned things a mapping delta uses:
      # parent_classification_name stores the *parent's* name, so they hang below the changed concept.
      # Resolved in the job - tens of thousands of ids are too many to travel as job arguments.
      #
      # Gated here so a scheme with no opted-in property, or a concept with no linked content, enqueues nothing.
      #
      # Accepted: linked_contents is transitive, so a whole-scheme relabel recomputes a content per ancestor.
      #
      # A cross-scheme move only covers the new scheme - the job re-reads the scheme at perform time.
      def add_linked_things_computed_properties_job(scheme_name = concept_scheme&.name)
        return if scheme_name.blank?
        return if DataCycleCore::ThingTemplate.classification_change_computed_properties_for(scheme_name).blank?
        return unless linked_contents.exists?

        DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'update_linked_things_computed_properties', nil)
      end

      def enqueue_thing_cache_jobs(thing_ids)
        return if thing_ids.blank?

        DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'update_things_search', thing_ids)
        DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'execute_things_webhooks_destroy', thing_ids) if concept_scheme&.trigger_webhooks?
      end

      def add_things_webhooks_job_destroy
        return unless concept_scheme&.trigger_webhooks? && assigned_things.exists?

        DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, id, 'execute_things_webhooks_destroy', assigned_things.pluck(:id))
      end

      def add_things_webhooks_job_update
        return if prevent_webhooks
        return unless concept_scheme&.trigger_webhooks? && assigned_things.exists?

        DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'execute_things_webhooks')
      end

      # Invalidated through the fan-out like the scheme path: #invalidate_things_cache covers the
      # same set, but runs in a CacheInvalidationJob under a concurrency key of its own, so nothing
      # orders it against this one.
      def execute_things_webhooks
        DataCycleCore::Content::RelatedWebhooks.fan_out(linked_contents, invalidate_related_cache: true)
      end

      def add_things_cache_invalidation_job
        DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'invalidate_things_cache')
      end

      def add_things_search_update_job
        DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'update_things_search')
      end

      def add_things_job_destroy
        return unless assigned_things.exists?

        DataCycleCore::CacheInvalidationDestroyJob.perform_later(
          self.class.name,
          id,
          'update_things_search',
          assigned_things.pluck(:id)
        )
      end

      # invalidate all linked things (direct and mapped) and their related things
      # ignore locked records to avoid deadlocks, as those are already invalidated by their transactions
      def invalidate_things_cache
        linked_contents
          .except(:includes)
          .lock('FOR UPDATE SKIP LOCKED')
          .with_cached_related_contents
          .invalidate_all
      end

      def update_things_search
        linked_contents.update_search_all
      end

      def clean_stored_filters
        DataCycleCore::Collection.remove_concept_id_from_parameters(id)
      end
    end
  end
end
