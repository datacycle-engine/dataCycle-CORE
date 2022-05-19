# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      module Classification
        class << self
          def keywords(computed_parameters:, **_args)
            DataCycleCore::Classification.where(id: Array.wrap(computed_parameters.values).flatten.reject(&:blank?)).pluck(:name).join(',')
          end

          def description(computed_parameters:, **_args)
            classification_ids = computed_parameters.values.flatten.reject(&:blank?)

            return if classification_ids.blank?

            DataCycleCore::Classification
              .where(id: classification_ids)
              .classification_aliases
              .map { |classification_alias| classification_alias.description || classification_alias.name || classification_alias.internal_name }
              &.join(',')
          end

          def value(computed_definition:, **_args)
            tree = computed_definition.dig('compute', 'tree')
            value = computed_definition.dig('compute', 'value')

            return if value.blank? || tree.blank?

            DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(tree, value)
          end
        end
      end
    end
  end
end
