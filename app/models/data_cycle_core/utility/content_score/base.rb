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

            parameter_keys = parameter_keys(content, key, properties)
            data_hash = load_missing_values(data_hash.try(:dc_deep_dup), content, parameter_keys)

            method_name = DataCycleCore::ModuleService
              .load_module(properties.dig('content_score', 'module').classify, 'Utility::ContentScore')
              .method(properties.dig('content_score', 'method'))

            data_hash[key] = method_name.call(
              key:,
              parameters: parameter_keys.index_with { |v| data_hash[v] },
              data_hash: data_hash || {},
              content:,
              definition: properties
            )&.to_f
          end

          def parameter_keys(content, key, properties)
            Array.wrap(properties&.dig('content_score', 'parameters'))
              .map { |p| p.split('.').first }
              .push(key)
              .compact
              .uniq
              .intersection(content.property_names)
          end

          def load_missing_values(datahash, content, parameter_keys)
            return datahash if parameter_keys.blank?

            datahash.merge!(content.get_data_hash_partial(parameter_keys.difference(datahash.keys)))
            datahash = DataCycleCore::DataHashService.flatten_datahash_translations_recursive(datahash)

            datahash.keys.intersection(content.embedded_property_names).each do |key|
              datahash[key]&.map! { |v| v.is_a?(::String) && v.uuid? ? DataCycleCore::Thing.find_by(id: v)&.get_data_hash : v }
            end

            datahash
          end

          def score_by_quantity(quantity, score_matrix)
            return 0 if score_matrix.blank? || score_matrix['min'].nil?

            quantity = quantity.to_r
            score_matrix = score_matrix.deep_dup.transform_values!(&:to_r)

            convert_to_scale = ->(value, min, max) { ((value - min) / (max - min)) * (100.0 - 1.0) + 1.0 }

            if score_matrix['optimal'].nil?
              quantity.between?(score_matrix['min'], score_matrix['max'] || Float::INFINITY) ? 1 : 0
            elsif quantity.between?(score_matrix['min'], score_matrix['optimal'])
              convert_to_scale.call(quantity, score_matrix['min'], score_matrix['optimal']) / 100
            elsif quantity.between?(score_matrix['optimal'], score_matrix['max'] || Float::INFINITY)
              return 1 if score_matrix['max'].nil?

              convert_to_scale.call(quantity, score_matrix['max'], score_matrix['optimal']) / 100
            else
              0
            end
          end

          def value_present?(data, key)
            DataCycleCore::DataHashService.deep_present?(DataCycleCore::Utility::Compute::Common.get_values_from_hash(data, key.split('.')))
          end

          def values_present(parameters, keys)
            required_count = keys.size
            present_count = 0

            keys.each do |key|
              present_count += 1 if DataCycleCore::Utility::ContentScore::Base.value_present?(parameters, key)
            end

            return present_count, required_count
          end

          def calculate_scores_by_method_or_presence(content:, parameters:)
            scores = {}

            parameters.each do |key, value|
              if key.in?(content.content_score_property_names)
                scores[key] = content.calculate_content_score(key, { key => value })
              else
                scores[key] = DataCycleCore::Utility::ContentScore::Base.value_present?(parameters, key) ? 1 : 0
              end
            end

            scores
          end

          def load_linked(parameters, key)
            parameters[key] = DataCycleCore::Thing.by_ordered_values(parameters[key]) if parameters[key].present?
          end
        end
      end
    end
  end
end
