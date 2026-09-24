# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Classification
        class << self
          def by_name(property_definition:, **_additional_args)
            value = if property_definition&.dig('default_value').is_a?(Hash)
                      property_definition&.dig('default_value', 'value')
                    else
                      property_definition&.dig('default_value')
                    end

            concepts = DataCycleCore::Concept.for_tree(property_definition&.dig('tree_label'))
              .with_internal_name(value)
            concepts = concepts.limit(property_definition.dig('validations', 'max').to_i) if property_definition.dig('validations', 'max').present?
            concepts.pluck(:id)
          end

          def schema_types(property_definition:, content:, **_args)
            content.thing_template.schema_types.flat_map do |path|
              find_classification(([property_definition['tree_label']] + path).join(' > '))
            end
          end

          def by_user_and_name(property_definition:, current_user:, **_additional_args)
            name = property_definition&.dig('default_value', 'value', current_user&.role&.name) ||
                   property_definition&.dig('default_value', 'value', 'all')

            DataCycleCore::Concept
              .for_tree(property_definition&.dig('tree_label'))
              .with_internal_name(name)
              .pluck(:id)
          end

          def by_user_and_concept_id(property_definition:, current_user:, **_additional_args)
            concept_id = property_definition&.dig('default_value', 'value', current_user&.role&.name) ||
                         property_definition&.dig('default_value', 'value', 'all')

            DataCycleCore::Concept.where(id: concept_id).pluck(:id)
          end

          def by_user_or_group_and_name(property_definition:, current_user:, **_additional_args)
            name = property_definition&.dig('default_value', 'value', current_user&.role&.name) ||
                   property_definition&.dig('default_value', 'value')&.values_at(*current_user&.user_groups&.pluck(:name)&.compact)&.first ||
                   property_definition&.dig('default_value', 'value', 'all')

            DataCycleCore::Concept
              .for_tree(property_definition&.dig('tree_label'))
              .with_internal_name(name)
              .pluck(:id)
          end

          def copy_from_string(property_definition:, data_hash:, **_additional_args)
            names = Array.wrap(property_definition.dig('default_value', 'parameters')).map { |path|
              data_hash.dig(*path.split('.'))
            }.flatten.uniq

            query = DataCycleCore::Concept
              .for_tree(property_definition['tree_label'])
              .with_internal_name(names)
            query = query.limit(1) if property_definition.dig('validations', 'max') == 1

            query.pluck(:id)
          end

          def by_name_and_external_source(property_definition:, content:, **_additional_args)
            mapping = property_definition.dig('default_value', 'value')

            return [] if mapping.blank?

            value = mapping[content.external_source.name] || mapping[content.external_source.identifier] if content&.external_source.present?
            value = mapping['default'] if value.blank?

            return [] if value.blank?

            DataCycleCore::Concept.for_tree(property_definition&.dig('tree_label')).with_internal_name(value).pluck(:id)
          end

          private

          def find_classification(path)
            return [] if path.blank?

            DataCycleCore::Concept.by_full_paths(path).limit(1).pluck(:id).compact
          end
        end
      end
    end
  end
end
