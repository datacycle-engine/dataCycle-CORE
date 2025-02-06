# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Classification
        class << self
          def by_name(property_definition:, **_additional_args)
            if property_definition&.dig('default_value').is_a?(Hash)
              value = property_definition&.dig('default_value', 'value')
            else
              value = property_definition&.dig('default_value')
            end

            concepts = DataCycleCore::Concept.for_tree(property_definition&.dig('tree_label'))
              .with_internal_name(value)
            concepts = concepts.limit(property_definition.dig('validations', 'max').to_i) if property_definition.dig('validations', 'max').present?
            concepts.pluck(:classification_id)
          end

          def schema_types(property_definition:, content:, **_args)
            schema_types = []

            if content.schema_ancestors.present?
              content.schema_ancestors.each do |path|
                schema_types.concat(
                  find_classification(transform_path(path, content, property_definition['tree_label']))
                )
              end
            elsif content.schema_type.present?
              schema_types.concat(
                find_classification(transform_path([content.schema_type], content, property_definition['tree_label']))
              )
            end

            schema_types.compact
          end

          def by_user_and_name(property_definition:, current_user:, **_additional_args)
            name = property_definition&.dig('default_value', 'value', current_user&.role&.name) ||
                   property_definition&.dig('default_value', 'value', 'all')

            DataCycleCore::Concept
              .for_tree(property_definition&.dig('tree_label'))
              .with_internal_name(name)
              .pluck(:classification_id)
          end

          def by_user_and_concept_id(property_definition:, current_user:, **_additional_args)
            concept_id = property_definition&.dig('default_value', 'value', current_user&.role&.name) ||
                         property_definition&.dig('default_value', 'value', 'all')

            DataCycleCore::Concept.where(id: concept_id).pluck(:classification_id)
          end

          def by_user_or_group_and_name(property_definition:, current_user:, **_additional_args)
            name = property_definition&.dig('default_value', 'value', current_user&.role&.name) ||
                   property_definition&.dig('default_value', 'value')&.values_at(*current_user&.user_groups&.pluck(:name)&.compact)&.first ||
                   property_definition&.dig('default_value', 'value', 'all')

            DataCycleCore::Concept
              .for_tree(property_definition&.dig('tree_label'))
              .with_internal_name(name)
              .pluck(:classification_id)
          end

          def copy_from_string(property_definition:, data_hash:, **_additional_args)
            names = Array.wrap(property_definition.dig('default_value', 'parameters')).map { |path|
              data_hash.dig(*path.split('.'))
            }.flatten.uniq

            query = DataCycleCore::ClassificationAlias
              .for_tree(property_definition['tree_label'])
              .with_internal_name(names)
              .primary_classifications
            query = query.limit(1) if property_definition.dig('validations', 'max') == 1

            query.pluck(:id)
          end

          def by_name_and_external_source(property_definition:, content:, **_additional_args)
            mapping = property_definition.dig('default_value', 'value')

            return [] if mapping.blank?

            value = mapping[content.external_source.name] || mapping[content.external_source.identifier] if content&.external_source.present?
            value = mapping['default'] if value.blank?

            return [] if value.blank?

            DataCycleCore::Concept.for_tree(property_definition&.dig('tree_label')).with_internal_name(value).pluck(:classification_id)
          end

          private

          def transform_path(path, content, tree_label)
            path.push("dcls:#{content.template_name}") if path.last != content.template_name

            ([tree_label] + path).join(' > ')
          end

          def find_classification(path)
            return [] if path.blank?

            DataCycleCore::Concept.by_full_paths(path).limit(1).pluck(:classification_id).compact
          end
        end
      end
    end
  end
end
