# frozen_string_literal: true

module DataCycleCore
  module ConceptSchemeExtensions
    # What a scheme change owes the contents its concepts classify - the api cache, the search index
    # and the webhooks - plus the CCC rewrite a hidden_mappings flip forces.
    module CacheInvalidation
      extend ActiveSupport::Concern

      CCC_REFRESH_BATCH_SIZE = 1_000

      included do
        after_update :add_things_cache_invalidation_job_update, if: :trigger_things_cache_invalidation?
        after_update :add_things_webhooks_job_update, if: :trigger_things_webhooks?
        # Redmine #50677: hidden_mappings changes which concepts of this scheme the mapped contents
        # effectively carry, so collected_concept_contents, the search index and the webhooks of every
        # affected content have to be handled. Always async: a flagged scheme can hold thousands of
        # mappings.
        #
        # This callback is the *only* thing that materialises the flag. collected_concept_contents.hidden
        # is kept in sync by the trigger functions, so it is never wrong for a write that goes through
        # them - but a write that skips the model (upsert_all in the concept importer, an update_all, a
        # manual UPDATE) leaves the already-materialised rows behind, and a hidden concept gives no
        # visible sign of being stale. Deliberately not a DB trigger: the refresh rewrites CCC for every
        # content reaching the scheme (six figures on a large one), which is exactly the work this job
        # exists to keep out of the writing transaction. After such a write, queue it by hand:
        #   DataCycleCore::CacheInvalidationJob.perform_later('DataCycleCore::ConceptScheme', id, 'refresh_hidden_mappings')
        after_update :add_hidden_mappings_job_update, if: :saved_change_to_hidden_mappings?
        after_destroy :clean_stored_filters
      end

      private

      def trigger_things_cache_invalidation?
        cached_attributes_changed?
      end

      # #50677: an update that also flips hidden_mappings is webhooked by refresh_hidden_mappings instead,
      # over the contents that *reach* the scheme - a superset of `things`, so nothing is lost by stepping
      # aside here, while running both would deliver every directly classified content twice.
      def trigger_things_webhooks?
        trigger_webhooks? && cached_attributes_changed? && !saved_change_to_hidden_mappings?
      end

      def cached_attributes_changed?
        return @cached_attributes_changed if defined? @cached_attributes_changed

        # NB: hidden_mappings is deliberately absent - the contents it changes are the ones reaching this
        # scheme through a mapping, which `things` (the directly classified contents) does not contain.
        # refresh_hidden_mappings handles them over the set it materialises CCC for.
        @cached_attributes_changed = saved_changes.key?('name') ||
                                     saved_changes.dig('visibility', 0)&.to_set&.^(saved_changes.dig('visibility', 1)&.to_set)&.include?('api')
      end

      def add_things_webhooks_job_update
        return unless things.exists?

        DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'execute_things_webhooks')
      end

      # Invalidated from here rather than left to #invalidate_things_cache: that one lifts the directly
      # classified contents, not the ones linking them that the fan-out re-exports, and it runs in a
      # CacheInvalidationJob of its own with no ordering against this one.
      def execute_things_webhooks
        DataCycleCore::Content::RelatedWebhooks.fan_out(things, invalidate_related_cache: true)
      end

      def add_things_cache_invalidation_job_update
        DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'invalidate_things_cache')
      end

      def invalidate_things_cache
        things.invalidate_all
      end

      def add_hidden_mappings_job_update
        DataCycleCore::CacheInvalidationJob.perform_later(self.class.name, id, 'refresh_hidden_mappings')
      end

      # Redmine #50677: collected_concept_contents.hidden is derived per (path, concept) from this
      # scheme's hidden_mappings flag, so flipping it only has to re-materialise the CCC rows of this
      # scheme's own concepts - not a single path row: concept_paths_transitive.mapped_ids ("reached
      # through a mapping") is pure path structure and does not depend on the flag. Batched, because a
      # flagged scheme can carry thousands of concepts and every batch touches all contents that reach
      # them.
      #
      # Search index and webhooks are refreshed from here, over the contents that reach the scheme, rather
      # than through cached_attributes_changed? - its `things` are the *directly* classified contents, which
      # leaves out every content that only reaches the scheme through a mapping, i.e. exactly the ones the
      # flag changes. cache_valid_since needs no help: invalidate_things_trigger on
      # collected_concept_contents bumps it for every non-'broader' row this rewrites, and a content whose
      # broader rows flip always has one - the mapped concept itself sorts deepest in its path partition, so
      # it holds the 'related' row and flips together with its ancestors.
      def refresh_hidden_mappings
        concept_ids = concepts.reorder(nil).ids
        return if concept_ids.blank?

        affected_things = DataCycleCore::Thing.where(id: DataCycleCore::CollectedConceptContent.where(concept_id: concept_ids).select(:thing_id))

        if DataCycleCore::Feature::TransitiveClassificationPath.enabled?
          concept_ids.each_slice(CCC_REFRESH_BATCH_SIZE) do |ids|
            execute_ccc_refresh('SELECT public.generate_ccc_from_concept_ids_transitive(ARRAY[?]::uuid[])', ids)
          end
        else
          affected_things.in_batches(of: CCC_REFRESH_BATCH_SIZE) do |batch|
            execute_ccc_refresh('SELECT public.generate_collected_concept_content_relations(ARRAY[?]::uuid[])', batch.ids)
          end
        end

        enqueue_hidden_mappings_side_effects(affected_things)
      end

      # Fanned out rather than run inline: both are a find_each over a set the CCC half above has already
      # spent its batches on, so keeping them here would put six figures of re-indexing and webhook
      # deliveries behind a single job that restarts from zero - redoing nothing of the committed CCC work
      # but all of its own - on any failure.
      def enqueue_hidden_mappings_side_effects(affected_things)
        affected_things.in_batches(of: CCC_REFRESH_BATCH_SIZE).each_with_index do |batch, index|
          thing_ids = batch.ids

          # the batch index belongs in arguments[1]: CacheInvalidationDestroyJob dedups on
          # (queue, delayed_reference_id, delayed_reference_type) = (arguments[1], "class#method"), so a
          # bare id would make each batch delete the ones enqueued before it. Neither method reads it.
          DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, "#{id}:#{index}", 'update_things_search', thing_ids)
          DataCycleCore::CacheInvalidationDestroyJob.perform_later(self.class.name, "#{id}:#{index}", 'execute_things_webhooks_destroy', thing_ids) if trigger_webhooks?
        end
      end

      def execute_ccc_refresh(sql, ids)
        return if ids.blank?

        self.class.transaction do
          self.class.connection.execute('SET LOCAL statement_timeout = 0')
          self.class.connection.execute(self.class.sanitize_sql([sql, ids]))
        end
      end

      def clean_stored_filters
        DataCycleCore::Collection.remove_concept_id_from_parameters(id)
      end
    end
  end
end
