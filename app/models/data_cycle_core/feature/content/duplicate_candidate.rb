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

        def original
          return @original if defined? @original

          @original = original_id.present? ? DataCycleCore::Thing.find_by(id: original_id) : nil
        end
      end
    end
  end
end
