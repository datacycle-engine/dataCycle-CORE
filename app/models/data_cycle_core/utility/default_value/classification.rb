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
                schema_types.concat(find_or_create_classification(path + [content.template_name], property_definition['tree_label'], true))
              end
            else
              schema_types.concat(find_or_create_classification([content.template_name], property_definition['tree_label'], true))
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

          private

          def find_or_create_classification(path, tree_label_name, internal = false)
            return [] if path.blank? || tree_label_name.blank?

            DataCycleCore::ClassificationAlias
              .for_tree(tree_label_name)
              .includes(:classification_alias_path)
              .where(classification_alias_paths: { full_path_names: path.reverse + [tree_label_name] })
              .primary_classifications
              .limit(1)
              .pluck(:id)
              .presence || Array.wrap(DataCycleCore::ClassificationTreeLabel.find_by(name: tree_label_name)&.create_classification_alias(*path.map { |p| { name: p, internal: internal } })&.primary_classification&.id).compact
          end
        end
      end
    end
  end
end
