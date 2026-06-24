# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module DuplicateCandidate
        # boolean filter for whether there are any duplicates for a thing
        def duplicate_candidates(value)
          subquery = DataCycleCore::Thing::DuplicateCandidate.without_fp
          subquery = subquery.where('duplicate_candidates.original_id = things.id')
            .select(1)
            .arel.exists

          if value.to_s == 'true'
            reflect(@query.where(subquery))
          else
            reflect(@query.where.not(subquery))
          end
        end

        def duplicate_candidate_filter(value)
          subquery = duplicate_candidate_filter_subquery(value)
          return self if subquery.nil?

          reflect(@query.where(subquery))
        end

        def not_duplicate_candidate_filter(value)
          subquery = duplicate_candidate_filter_subquery(value)
          return self if subquery.nil?

          reflect(@query.where.not(subquery))
        end

        private

        def duplicate_candidate_filter_subquery(value)
          return if value.blank?

          duplicate_method = value['method']
          min_score = value['min'].presence&.to_f
          max_score = value['max'].presence&.to_f
          min_score, max_score = max_score, min_score if min_score.present? && max_score.present? && min_score > max_score

          subquery = DataCycleCore::Thing::DuplicateCandidate.without_fp
          subquery = subquery.where(score: min_score.to_i..) if min_score.present?
          subquery = subquery.where(score: ..max_score.to_i) if max_score.present?
          subquery = subquery.where(duplicate_method:) if duplicate_method.present? && duplicate_method != 'all'

          subquery.where('duplicate_candidates.original_id = things.id')
            .select(1)
            .arel.exists
        end
      end
    end
  end
end
