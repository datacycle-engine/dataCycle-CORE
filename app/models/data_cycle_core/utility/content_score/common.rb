# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Common
        extend Extensions::Tooltip
        extend Extensions::TooltipScoreMatrix

        class << self
          def by_quantity(definition:, data_hash:, key:, **_args)
            Base.score_by_quantity(
              data_hash[key]&.size.to_i,
              definition.dig('content_score', 'score_matrix')
            )
          end

          def by_presence(key:, parameters:, **_args)
            Base.value_present?(parameters, key) ? 1 : 0
          end

          def by_cc_license(content:, **_args)
            license_classifications = content
              &.classification_aliases
              &.includes(:classification_tree_label)
              &.where(classification_tree_labels: { name: content&.properties_for('license_classification')&.dig('tree_label') })

            if license_classifications.present? && license_classifications&.all? { |c| c.try(:uri)&.starts_with?('https://creativecommons.org/') }
              1
            else
              0
            end
          end
        end
      end
    end
  end
end
