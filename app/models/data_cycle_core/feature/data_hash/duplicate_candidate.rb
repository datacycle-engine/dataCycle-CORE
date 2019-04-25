# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module DuplicateCandidate
        def create_duplicate_candidates
          duplicates = duplicate_method
          return if duplicates.blank?

          duplicates.each do |duplicate|
            thing_duplicates.create!(thing_duplicate_id: duplicate[:content]&.id, method: duplicate[:method], score: duplicate[:score]) unless duplicate_candidates.any? { |c| c.duplicate_id == duplicate[:content]&.id }
          end
        end
      end
    end
  end
end
