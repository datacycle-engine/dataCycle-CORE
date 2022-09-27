# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module DuplicateCandidate
        def after_save_data_hash(options)
          super

          # add job to check for possible duplicates and add them as duplicate_candidates
          add_check_for_duplicates_job if options.new_content &&
                                          options.check_for_duplicates &&
                                          !embedded? &&
                                          duplicate_method?
        end

        def create_duplicate_candidates
          duplicates = duplicate_method

          duplicate_candidates.where.not(duplicate_id: duplicates&.pluck(:thing_duplicate_id)&.compact).thing_duplicates.delete_all

          timestamp = Time.zone.now

          duplicates.present? ? thing_duplicates.insert_all(duplicates.each { |v| v.merge!({ created_at: timestamp, updated_at: timestamp }) }, unique_by: :unique_thing_duplicate_idx).count : 0
        end

        def merge_with_duplicate(duplicate)
          DataCycleCore::MergeDuplicateJob.perform_later(id, duplicate.id)

          DataCycleCore::Thing.find_by(id: duplicate.id)&.duplicate_candidates&.thing_duplicates&.delete_all
        end

        private

        def add_check_for_duplicates_job
          DataCycleCore::CheckForDuplicatesJob.perform_later(id)
        end
      end
    end
  end
end
