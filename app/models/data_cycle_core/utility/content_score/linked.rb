# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Linked
        extend Extensions::Tooltip

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

          def to_tooltip(_content, definition, locale)
            tooltip = [tooltip_base_string(definition.dig('content_score', 'method'), locale: locale)]

            if definition.dig('content_score', 'weight_matrix').present?
              subtips = ['<ul>']
              definition.dig('content_score', 'weight_matrix')
              .sort_by { |k, _v| k }
              .each do |k, v|
                subtips.push("<li><b>#{tooltip_string("weight_matrix_keys.#{k}", locale: locale, default: k.capitalize)}</b> (#{(v.to_r * 100).round}%)</li>")
              end
              tooltip.push("#{subtips.join}</ul>")
            end

            tooltip.compact.join('<br>')
          end
        end
      end
    end
  end
end
