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

          def by_first_linked_score(parameters:, key:, **_args)
            return 0 if parameters[key].blank?

            linked_item = DataCycleCore::Thing.find_by(id: parameters[key]&.first)

            linked_item.try(:internal_content_score).to_f / 100
          end

          def by_linked_score_and_weights(definition:, parameters:, key:, **_args)
            DataCycleCore::Utility::ContentScore::Base.load_linked(parameters, key)

            count = parameters[key]&.count { |l| l.try(:internal_content_score).to_i >= definition.dig('content_score', 'min_score').to_i } || 0

            if definition.dig('content_score', 'weight_matrix')&.key?(count.to_s)
              definition.dig('content_score', 'weight_matrix', count.to_s).to_r
            elsif count.positive? && definition.dig('content_score', 'weight_matrix')&.key?('many')
              definition.dig('content_score', 'weight_matrix', 'many').to_r
            else
              0
            end
          end

          def to_tooltip(_content, definition, locale)
            tooltip = [
              tooltip_base_string(
                definition.dig('content_score', 'method'),
                locale:,
                score: definition.dig('content_score', 'min_score')
              )
            ]

            if definition.dig('content_score', 'weight_matrix').present?
              subtips = ['<ul>']
              definition.dig('content_score', 'weight_matrix')
                .sort_by { |k, _v| k }
                .each do |k, v|
                subtips.push("<li><b>#{tooltip_string("weight_matrix_keys.#{k}", locale:, default: k.capitalize)}</b> (#{(v.to_r * 100).round}%)</li>")
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
