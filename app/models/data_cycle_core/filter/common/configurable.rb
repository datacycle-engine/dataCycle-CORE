# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module Configurable

        def with_classification_aliases_and_treename(definition)
          return self if definition.blank?
          raise StandardError, 'Missing data definition: treeLabel' if definition.dig('treeLabel').blank?
          raise StandardError, 'Missing data definition: aliases' if definition.dig('aliases').blank?

          with_classification_aliases(definition.dig('treeLabel'), definition.dig('aliases'))
        end

        def with_external_source_names(definition)
          return self if definition.blank?
          raise StandardError, 'Missing data definition: names' if definition.dig('names').blank?

          ids = DataCycleCore::ExternalSource.where(name: definition.dig('names').flatten)&.map(&:id)

          external_source(ids)
        end

      end
    end
  end
end
