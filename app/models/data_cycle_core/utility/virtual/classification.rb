# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Classification
        class << self
          def concat(virtual_parameters:, content:, virtual_definition:, **_args)
            values = []

            virtual_parameters.each do |param|
              values << classifcation_alias_value(content.send(param), virtual_definition.dig(:virtual, :key))
            end

            values.compact_blank!

            return if values.empty?

            values.join(', ')
          end

          def by_tree_label(content:, virtual_definition:, **_args)
            return if virtual_definition['tree_label'].blank?

            content.classification_aliases.for_tree(virtual_definition['tree_label']).primary_classifications
          end

          def classifcation_alias_value(classifications, key)
            if classifications.loaded?
              aliases = classifications&.map(&:classification_aliases)&.flatten
            else
              aliases = classifications&.classification_aliases
            end

            aliases&.map { |ca| ca.send(key) || ca.internal_name }
          end

          def to_mapped_value(virtual_parameters:, content:, virtual_definition:, **_args)
            values = virtual_parameters&.map { |v| content.try(v)&.pluck(:name) }&.flatten&.map { |v| virtual_definition.dig('virtual', 'mapping', v) }

            if virtual_definition['type'] == 'boolean'
              values&.first
            else
              values
            end
          end
        end
      end
    end
  end
end
