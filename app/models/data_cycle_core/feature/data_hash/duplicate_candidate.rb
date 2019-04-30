# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module DuplicateCandidate
        def create_duplicate_candidates
          duplicates = duplicate_method
          return if duplicates.blank?

          duplicates.each do |duplicate|
            thing_duplicates.create!(thing_duplicate_id: duplicate[:content]&.id, method: duplicate[:method], score: duplicate[:score]) unless duplicate_candidates.with_fp.any? { |c| c.duplicate_id == duplicate[:content]&.id }
          end
        end

        def merge_with_duplicate(duplicate)
          return if template_name != duplicate.template_name

          duplicate.content_content_b.where.not(content_a_id: content_content_b.map(&:content_a_id)).update_all(content_b_id: id) # rubocop:disable Rails/SkipsModelValidations
          duplicate.content_content_b_history.where.not(content_a_history_id: content_content_b_history.map(&:content_a_history_id)).update_all(content_b_history_id: id) # rubocop:disable Rails/SkipsModelValidations

          duplicate.destroy_content
        end
      end
    end
  end
end
