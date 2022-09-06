# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module ContentScore
        class << self
          def calculate_from_feature(content:, data_hash:, **_args)
            return unless content.try(:content_score_allowed?)

            (content.calculate_content_score(nil, data_hash).to_f * 100).round
          end
        end
      end
    end
  end
end
