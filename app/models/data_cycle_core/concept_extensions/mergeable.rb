# frozen_string_literal: true

module DataCycleCore
  module ConceptExtensions
    # Folding one concept into another: what moves over, and what a merge does with the
    # (external_system_id, external_key) pair the source carries.
    #
    # index_concepts_on_external_system_id_and_external_key is unique over that pair, and the
    # importers resolve a concept through it, so the pair a merge leaves behind decides whether the
    # next run updates the target or inserts the duplicate all over again. #merge_with calls the
    # guard before it moves anything and the hand-over after the source is gone.
    module Mergeable
      extend ActiveSupport::Concern

      def merge_children_into_self
        descendants.find_each do |d|
          d.prevent_webhooks = prevent_webhooks
          d.merge_with(self)
        end
      end

      def merge_with_children(new_concept, destroy_children: false)
        transaction do
          ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')

          if destroy_children
            merge_children_into_self
          else
            # concepts_propagate_scheme_trigger only fires on a concepts UPDATE, and this one writes
            # concept_links, so the children carry their own scheme over to their new parent's.
            children.reorder(nil).where.not(concept_scheme_id: new_concept.concept_scheme_id).update_all(concept_scheme_id: new_concept.concept_scheme_id, updated_at: Time.zone.now)
            children_concept_links.update_all(parent_id: new_concept.id)
          end

          merge_with(new_concept)
        end
      end

      def merge_with(new_concept)
        ensure_external_system_mergeable!(new_concept)

        move_mappings_to(new_concept)
        move_contents_to(new_concept)

        concept_polygons.update_all(concept_id: new_concept.id)

        concept_user_groups
          .where.not('EXISTS (SELECT 1 FROM concept_user_groups cug WHERE cug.user_group_id = concept_user_groups.user_group_id AND cug.concept_id = ?)', new_concept.id)
          .update_all(concept_id: new_concept.id)

        DataCycleCore::StoredFilter
          .where(id: DataCycleCore::StoredFilter.where('parameters::TEXT ILIKE ?', "%#{id}%").lock('FOR UPDATE SKIP LOCKED').order(:id).select(:id))
          .update_all("parameters = replace(parameters::text, '#{id}', '#{new_concept.id}')::jsonb")

        destroy

        # after destroy: our (external_system_id, external_key) is free again, so the target can take
        # it over without tripping the unique index
        move_external_system_to(new_concept)

        new_concept.send(:add_things_cache_invalidation_job)
        new_concept.send(:add_things_search_update_job)
        new_concept.send(:add_things_webhooks_job_update)
      end

      private

      # Both directions of the mapping: the concepts we map to, and the ones mapping to us. Skipping
      # the pairs the target already holds keeps index_concept_links_on_parent_id_and_child_id happy,
      # and the self-links a merge would otherwise create (we map to the target, or it to us) are
      # dropped with our own rows.
      def move_mappings_to(new_concept)
        mapped_concept_links
          .where.not(child_id: new_concept.id)
          .where.not('EXISTS (SELECT 1 FROM concept_links cl WHERE cl.link_type = concept_links.link_type AND cl.child_id = concept_links.child_id AND cl.parent_id = ?)', new_concept.id)
          .update_all(parent_id: new_concept.id)

        mapped_inverse_concept_links
          .where.not(parent_id: new_concept.id)
          .where.not('EXISTS (SELECT 1 FROM concept_links cl WHERE cl.link_type = concept_links.link_type AND cl.parent_id = concept_links.parent_id AND cl.child_id = ?)', new_concept.id)
          .update_all(child_id: new_concept.id)
      end

      def move_contents_to(new_concept)
        concept_contents
          .where.not('EXISTS (SELECT 1 FROM concept_contents cc WHERE cc.content_data_id = concept_contents.content_data_id AND cc.relation = concept_contents.relation AND cc.concept_id = ?)', new_concept.id)
          .update_all(concept_id: new_concept.id)

        concept_content_histories
          .where.not('EXISTS (SELECT 1 FROM concept_content_histories cch WHERE cch.content_data_history_id = concept_content_histories.content_data_history_id AND cch.relation = concept_content_histories.relation AND cch.concept_id = ?)', new_concept.id)
          .update_all(concept_id: new_concept.id)
      end

      # Redmine #51232: a merge that destroys the system-owned side loses its external key, and the
      # importer's ON CONFLICT only finds a live row - so the next run recreates the concept instead
      # of updating the target, and the duplicate is back.
      #
      # Two keys of one system are that system's own duplicate, so merging them is the operator
      # asserting the system will stop delivering the source key: while it still delivers both
      # ('<uuid> - Discounted' next to '<uuid>_2 - Discounted'), the next run inserts ours again. Two
      # systems carry no such assertion, and nothing else tells the two cases apart - the unique index
      # and move_external_system_to treat same- and cross-system identically.
      #
      # A target keyed without a system is refused on its own account: it is the one target
      # move_external_system_to would overwrite, while a target holding a real system and a key of
      # its own keeps them. A bare-keyed source has nothing to hand over, so it merges into any
      # target; #51232's own duplicate is that shape and returns at the first guard.
      def ensure_external_system_mergeable!(new_concept)
        return if external_system_id.nil?
        return if new_concept.external_system_id.nil? && new_concept.external_key.nil?
        return if external_system_id == new_concept.external_system_id

        raise DataCycleCore::Error::AmbiguousConceptExternalSystemError.new(self, new_concept)
      end

      # Hands our external identity to a target that carries none, so the next import updates the
      # target instead of inserting a new concept. Nothing is released first: the source row is hard
      # deleted, which frees the pair outright.
      def move_external_system_to(new_concept)
        return if external_system_id.nil?

        # The slot our key needs is the target's external_key, not its external_system_id: a target
        # on (<feratel>, NULL) has room for ours and would otherwise leave 'SOURCE-KEY' on no row at
        # all. Both columns are written together, so a target that already carries a system is still
        # left alone when we have no key to put in it - the importer matches a blank-key concept on
        # (external_system_id, internal_name), which that write would redirect.
        return if new_concept.external_key.present?
        return if new_concept.external_system_id.present? && external_key.nil?

        new_concept.update_columns(external_system_id:, external_key:, updated_at: Time.zone.now)
      end
    end
  end
end
