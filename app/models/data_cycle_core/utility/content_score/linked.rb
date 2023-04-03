# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Linked
        class << self
          def by_linked_weight_matrix(parameters:, definition:, key:, **_args)
            linked_items = DataCycleCore::Thing.where(id: parameters[key])
            scores = linked_items.map do |item|
              parameter_keys = Base.parameter_keys(item, nil, ActiveSupport::HashWithIndifferentAccess.new({ content_score: { parameters: definition.dig('content_score', 'weight_matrix').keys } }))
              data_hash = item.get_data_hash_partial(parameter_keys)
              linked_scores = Base.calculate_scores_by_method_or_presence(
                content: item,
                parameters: parameter_keys.index_with { |v| data_hash[v] }
              )

              definition.dig('content_score', 'weight_matrix')&.sum { |k, v| linked_scores[k].to_f * v.to_r }
            end

            return 0 if scores.blank?

            scores.sum / scores.size
          end
        end
      end
    end
  end
end
