# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Content
      module DuplicateCandidate
        def duplicate_method
          case template_name
          when 'Bild'
            asset&.duplicate_candidates_with_score
          when 'Organization', 'POI'
            DataCycleCore::Filter::Search.new([:de]).fulltext_search(name).where(template_name: template_name).map { |c| { content: c, method: 'fulltext', score: 100 } }
          end
        end
      end
    end
  end
end
