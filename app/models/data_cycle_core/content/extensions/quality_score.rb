# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      module QualityScore
        def calculate_quality_score(key, datahash)
          DataCycleCore::Utility::QualityScore::Base.calculate_quality_score(key, datahash, self)
        end
      end
    end
  end
end
