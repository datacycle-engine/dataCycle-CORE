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

          duplicate_candidates.where.not(duplicate_id: duplicates&.map { |d| d[:content]&.id }&.compact).thing_duplicates.delete_all

          duplicates&.each do |duplicate|
            thing_duplicates.create!(thing_duplicate_id: duplicate[:content]&.id, method: duplicate[:method], score: duplicate[:score]) unless duplicate_candidates.with_fp.any? { |c| c.duplicate_id == duplicate[:content]&.id }
          end
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
