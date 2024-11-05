# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module String
        class << self
          def concat(computed_parameters:, computed_definition:, **_args)
            computed_parameters.values.flatten.join(computed_definition&.dig('compute', 'separator').to_s)
          end

          def value(computed_definition:, **_args)
            computed_definition.dig('compute', 'value')
          end

          def interpolate(computed_parameters:, content:, computed_definition:, **_args)
            format(computed_definition&.dig('compute', 'value').to_s, {
              locale: I18n.locale,
              created_at: content&.created_at,
              external_key: content&.external_key
            }.merge(computed_parameters.symbolize_keys))
          end

          def interpolate_outdoor_active_tour_url(computed_parameters:, content:, computed_definition:, **_args)
            format(computed_definition&.dig('compute', 'value').to_s, {
              external_key: content&.external_key,
              outdoor_active_tour_base_url: content&.external_source&.default_options&.dig('outdoor_active_tour_base_url')
            }.reverse_merge(computed_parameters.symbolize_keys))
          end

          def interpolate_outdoor_active_poi_url(computed_parameters:, content:, computed_definition:, **_args)
            format(computed_definition&.dig('compute', 'value').to_s, {
              external_key: content&.external_key,
              outdoor_active_poi_base_url: content&.external_source&.default_options&.dig('outdoor_active_poi_base_url')
            }.reverse_merge(computed_parameters.symbolize_keys))
          end

          def number_of_characters(computed_definition:, data_hash:, **_args)
            recursive_char_count(data_hash, computed_definition.dig('compute', 'paths'))&.flatten&.compact&.sum
          end

          def linked_gip_route_attribute(computed_parameters:, computed_definition:, **_args)
            content = DataCycleCore::Thing.find_by(id: computed_parameters.values.first)

            content&.send(computed_definition&.dig('compute', 'linked_attribute').to_s)
          end

          def parent_classification_name(computed_parameters:, computed_definition:, **_args)
            classifications = computed_parameters.values.flatten
            return nil if classifications.blank?

            tree_label = computed_definition.dig('compute', 'tree_label')
            return nil if tree_label.blank?

            DataCycleCore::Concept.for_tree(tree_label).find_by(classification_id: classifications)&.parent&.name
          end

          private

          def recursive_char_count(data, parameters)
            return if parameters.blank? || data.blank?

            parameters.map do |parameter|
              if parameter.is_a?(::Hash)
                parameter.map do |k, v|
                  data[k]&.map do |s|
                    recursive_char_count(s, v)
                  end
                end
              else
                (
                  data.dig('translations', I18n.locale.to_s, parameter) ||
                  data.dig('datahash', parameter) ||
                  data[parameter]
                ).to_s.strip_tags.size
              end
            end
          end
        end
      end
    end
  end
end
