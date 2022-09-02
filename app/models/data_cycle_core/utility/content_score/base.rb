# frozen_string_literal: true

module DataCycleCore
  module Utility
    module ContentScore
      module Base
        class << self
          def calculate_content_score(key, data_hash, content)
            return unless DataCycleCore::Feature::ContentScore.enabled?

            properties = content.content_score_definition(key)

            return unless properties&.key?('content_score')

            parameters = Array.wrap(properties&.dig('content_score', 'parameters')).map { |p| p.split('.').first }.concat([key]).uniq.compact.intersection(content.property_names)

            data_hash = load_missing_values(data_hash, content, parameters)

            properties.dig('content_score', 'module')&.classify&.safe_constantize&.try(
              properties.dig('content_score', 'method'),
              key: key,
              parameters: parameters.index_with { |v| data_hash[v] },
              data_hash: data_hash || {},
              content: content,
              definition: properties
            )
          end

          def load_missing_values(datahash, content, parameters)
            return datahash if parameters.blank?

            datahash.merge!(content.get_data_hash_partial(parameters.difference(datahash.keys)))
            datahash = DataCycleCore::DataHashService.flatten_datahash_translations_recursive(datahash)

            datahash.keys.intersection(content.embedded_property_names).each do |key|
              datahash[key]&.map! { |v| v.is_a?(::String) && v.uuid? ? DataCycleCore::Thing.find_by(id: v)&.get_data_hash : v }
            end

            datahash
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
