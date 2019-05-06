# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module DuplicateCandidate
        def duplicate_method
          case template_name
          when 'Bild'
            asset&.duplicate_candidates_with_score
          end
        end
      end
    end
  end
end
