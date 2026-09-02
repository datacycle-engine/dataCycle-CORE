# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module DuplicateCandidate
        extend ActiveSupport::Concern

        def after_save_data_hash(options)
          super

          return if embedded?
          return unless duplicate_candidates_allowed?

          # add job to check for possible duplicates and add them as duplicate_candidates
          add_check_for_duplicates_job if affected_by_change?(saved_changes&.keys, options.template_changed)

          add_dependent_check_for_duplicates_job if cached_related_contents?
        end

        # Recalculates this content's duplicate candidates: everything the configured detection
        # modules no longer find is removed, everything they find is (re-)inserted. Pairs with a
        # reserved method (see Feature::DuplicateCandidate.reserved_methods) are kept - a user set
        # them explicitly and no module would ever re-find them. Rows without a method are still
        # cleaned up, so legacy data does not become undeletable.
        # @return [Integer] number of inserted candidate rows, 0 if one end of a pair was destroyed
        #   while its candidates were being computed
        def create_duplicate_candidates
          duplicates = find_duplicates
          to_delete = duplicate_candidates
          fp_duplicate_ids = []

          if duplicates.present?
            to_delete = to_delete.without_thing_method_pairs(duplicates.pluck(:thing_duplicate_id, :method))
            fp_duplicate_ids = duplicate_candidates.with_fp.distinct.reorder(nil).pluck(:duplicate_id)
          end

          to_delete = to_delete.where.not(duplicate_method: Feature::DuplicateCandidate.reserved_methods)
            .or(to_delete.where(duplicate_method: nil))

          duplicates&.each do |v|
            v[:thing_id] = id
            v[:false_positive] = fp_duplicate_ids.include?(v[:thing_duplicate_id])
          end

          # the delete and the insert have to commit together: on their own, anything that aborts
          # between them - a deadlock against a worker recalculating the other end of a pair, most
          # of all - leaves this content with its candidates removed and none written back
          ActiveRecord::Base.transaction do
            to_delete.thing_duplicates.delete_all

            next 0 if duplicates.blank?

            ThingDuplicate
              .insert_all(duplicates, unique_by: :unique_thing_duplicate_idx)
              .count
          end
        rescue ActiveRecord::InvalidForeignKey
          # both foreign keys of thing_duplicates point at things, so this only ever means one end of
          # a pair was destroyed between the modules reading it and the insert - a long dc:duplicates
          # run races the imports and cleanups doing exactly that. Its rows went with it (ON DELETE
          # CASCADE) and the transaction took the deletes back, so there is nothing left to do.
          Rails.logger.warn("[duplicate_candidates] skipped #{id}: one end of a pair was destroyed while its candidates were computed")
          0
        end

        # version + merge in one go, for bulk merges that have nothing to report back
        # (see lib/tasks/dc_duplicates.rake)
        def merge_with_duplicate_and_version(duplicate, current_user: nil, async: true)
          create_merge_version(duplicate, current_user:)

          merge_with_duplicate(duplicate, current_user:, async:)
        end

        # records the merge on the original as a named version. has to run before the merge
        # itself, otherwise a merge that fails part way through would stay unrecorded.
        def create_merge_version(duplicate, current_user: nil)
          I18n.with_locale(first_available_locale) do
            duplicate.original_id = id
            set_data_hash(data_hash: {}, version_name: Feature::DuplicateCandidate.version_name_for_merge(duplicate), force_update: true, current_user:)
          end
        end

        # async: hand the merge to MergeDuplicateJob and hide the pair in the meantime,
        # otherwise merge right away (the duplicate_candidates are removed by FK cascade)
        def merge_with_duplicate(duplicate, current_user: nil, async: true)
          return Feature::DuplicateCandidate.merge_duplicate(self, duplicate, current_user:) unless async

          MergeDuplicateJob.perform_later(id, duplicate.id, current_user&.id)

          Thing.find_by(id: duplicate.id)&.duplicate_candidates&.thing_duplicates&.delete_all
        end

        def mark_duplicate_as_false_positive(duplicate)
          duplicate.duplicate_candidates
            .where(duplicate_id: id)
            .thing_duplicates
            .update_all(false_positive: true)
        end

        def affected_by_change?(changed_attributes, template_changed = false)
          template_changed || changed_attributes&.intersect?(combined_parameters)
        end

        private

        def add_check_for_duplicates_job
          CheckForDuplicatesJob.perform_later(id)
        end

        def add_dependent_check_for_duplicates_job
          changed_keys = Array.wrap(datahash_changes&.keys)
          CheckDependentForDuplicatesJob.perform_later(id, changed_keys)
        end

        def add_destroy_check_for_duplicates_job
          id_attribute_hash = ContentContent::Link.id_attribute_hash(id)
          return if id_attribute_hash.blank?

          DestroyDependentForDuplicatesJob.perform_later(id, id_attribute_hash)
        end

        def combined_parameters
          Feature['DuplicateCandidate'].combined_parameters(self)
        end
      end
    end
  end
end
