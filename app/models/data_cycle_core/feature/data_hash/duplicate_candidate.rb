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

        def create_duplicate_candidates
          duplicates = find_duplicates
          to_delete = duplicate_candidates
          fp_duplicate_ids = []

          if duplicates.present?
            to_delete = to_delete.without_thing_method_pairs(duplicates&.pluck(:thing_duplicate_id, :method))
            fp_duplicate_ids = duplicate_candidates.with_fp.distinct.reorder(nil).pluck(:duplicate_id)
          end

          to_delete.thing_duplicates.delete_all

          return 0 if duplicates.blank?

          duplicates.each do |v|
            v[:thing_id] = id
            v[:false_positive] = fp_duplicate_ids.include?(v[:thing_duplicate_id])
          end

          ThingDuplicate
            .insert_all(duplicates, unique_by: :unique_thing_duplicate_idx)
            .count
        end

        def merge_with_duplicate_and_version(duplicate)
          I18n.with_locale(first_available_locale) do
            duplicate.original_id = id
            set_data_hash(data_hash: {}, version_name: Feature::DuplicateCandidate.version_name_for_merge(duplicate), force_update: true)
          end

          merge_with_duplicate(duplicate)
        end

        def merge_with_duplicate(duplicate)
          MergeDuplicateJob.perform_later(id, duplicate.id)

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
