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

            Array.wrap(DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(property_definition&.dig('tree_label'), value))
          end

          def schema_types(property_definition:, content:, **_args)
            schema_types = []

            if content.schema_ancestors.present?
              content.schema_ancestors.each do |path|
                schema_types.concat(
                  find_classification(transform_path(path, content), property_definition['tree_label'])
                )
              end
            elsif content.schema_type.present?
              schema_types.concat(
                find_classification(transform_path([content.schema_type], content), property_definition['tree_label'])
              )
            end

            schema_types.compact
          end

          def by_user_and_name(property_definition:, current_user:, **_additional_args)
            Array.wrap(
              DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(
                property_definition&.dig('tree_label'),
                property_definition&.dig('default_value', 'value', current_user&.role&.name) || property_definition&.dig('default_value', 'value', 'all')
              )
            )
          end

          def by_user_or_group_and_name(property_definition:, current_user:, **_additional_args)
            Array.wrap(
              DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(
                property_definition&.dig('tree_label'),
                property_definition&.dig('default_value', 'value', current_user&.role&.name) ||
                property_definition&.dig('default_value', 'value')&.values_at(*current_user&.user_groups&.pluck(:name)&.compact)&.first ||
                property_definition&.dig('default_value', 'value', 'all')
              )
            )
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

          private

          def transform_path(path, content)
            path.push("dcls:#{content.template_name}") if path.last != content.template_name

            path
          end

          def find_classification(path, tree_label_name)
            return [] if path.blank? || tree_label_name.blank?

            DataCycleCore::ClassificationAlias
              .for_tree(tree_label_name)
              .includes(:classification_alias_path)
              .where(classification_alias_paths: { full_path_names: path.reverse + [tree_label_name] })
              .primary_classifications
              .limit(1)
              .pluck(:id)
          end
        end
      end
    end
  end
end
