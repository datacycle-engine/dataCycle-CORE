# frozen_string_literal: true

module DataCycleCore
  module Utility
    module QualityScore
      module Base
        class << self
          def calculate_quality_score(key, data_hash, content)
            properties = content.properties_for(key)&.with_indifferent_access

            return unless properties&.key?('quality_score')

            parameters = Array.wrap(properties&.dig('quality_score', 'parameters')).map { |p| p.split('.').first }.concat([key]).uniq.intersection(content.property_names)

            load_missing_values(data_hash, content, parameters)

            properties.dig('quality_score', 'module')&.classify&.safe_constantize&.try(
              properties.dig('quality_score', 'method'),
              **{
                key: key,
                parameters: parameters.index_with { |v| data_hash[v] },
                data_hash: data_hash || {},
                content: content,
                definition: properties
              }
            )
          end

          def load_missing_values(datahash, content, parameters)
            return if parameters.blank?

            parameters.difference(datahash.keys).each do |missing_key|
              datahash[missing_key] = content.property_value_for_set_datahash(missing_key)
            end
          end

          def score_by_quantity(quantity, score_matrix)
            return 0 if score_matrix.blank? || score_matrix['min'].nil? || score_matrix['optimal'].nil?

            case quantity = quantity.to_i
            when score_matrix['min']...score_matrix['optimal']
              (quantity - score_matrix['min'] + 1) * (1.0 / (score_matrix['optimal'] - score_matrix['min'] + 1))
            when score_matrix['optimal']
              1
            when score_matrix['optimal']..(score_matrix['max'] || Float::INFINITY)
              return 1 if score_matrix['max'].nil?

              (score_matrix['max'] - quantity + 1) * (1.0 / (score_matrix['max'] - score_matrix['optimal'] + 1))
            else
              0
            end
          end
        end
      end
    end
  end
end
