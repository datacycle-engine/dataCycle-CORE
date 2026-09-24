# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module Classification
        class << self
          # example config:
          # :virtual:
          #   :module: Classification
          #   :method: concat
          #   :key: name
          #   :separator: " | " # optional
          #   :parameters:
          #     - some_classification_attribute
          #
          # ', ' stays the default for the configs that predate the option. A separator
          # configured as an empty string is used as such, it does not fall back.
          def concat(virtual_parameters:, content:, virtual_definition:, **_args)
            values = virtual_parameters.map do |param|
              concept_values(content.send(param), virtual_definition.dig(:virtual, :key))
            end

            values.compact_blank!

            return if values.empty?

            values.join(virtual_definition.dig(:virtual, :separator) || ', ')
          end

          def by_tree_label(content:, virtual_definition:, **_args)
            return if virtual_definition['tree_label'].blank?

            content.full_concepts
              .for_tree(virtual_definition['tree_label'])
          end

          # A classification property holds concepts since Redmine #41458; it used to hold
          # classifications and needed the hop to their aliases.
          def concept_values(concepts, key)
            concepts&.map { |concept| concept.send(key) || concept.internal_name }
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

            content.full_concepts.for_tree(concept_scheme).pick(key)
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

            content.full_concepts.for_tree(concept_scheme).pluck(key).join(', ')
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
