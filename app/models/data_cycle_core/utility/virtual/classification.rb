# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Classification
        class << self
          def concat(virtual_parameters:, content:, virtual_definition:, **_args)
            values = virtual_parameters.map do |param|
              classifcation_alias_value(content.send(param), virtual_definition.dig(:virtual, :key))
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

          # example config:
          # :virtual:
          #   :module: Classification
          #   :method: value_by_concept_scheme
          #   :key: uri
          #   :concept_scheme: Lizenzen
          def value_by_concept_scheme(content:, virtual_definition:, **_args)
            concept_scheme = virtual_definition.dig('virtual', 'concept_scheme')
            return if concept_scheme.blank?

            key = virtual_definition.dig(:virtual, :key).presence || 'internal_name'

            content.full_classification_aliases.for_tree(concept_scheme).pick(key)
          end

          # example config:
          # :virtual:
          #   :module: Classification
          #   :method: values_by_concept_scheme
          #   :key: uri
          #   :concept_scheme: Lizenzen
          def values_by_concept_scheme(content:, virtual_definition:, **_args)
            concept_scheme = virtual_definition.dig('virtual', 'concept_scheme')
            return if concept_scheme.blank?

            key = virtual_definition.dig(:virtual, :key).presence || 'internal_name'

            content.full_classification_aliases.for_tree(concept_scheme).pluck(key)
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
