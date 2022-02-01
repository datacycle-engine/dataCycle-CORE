# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Asset
        def self.file_type_classification(property_parameters:, property_definition:, **_args)
          file_types = DataCycleCore::Asset.find_by(id: property_parameters&.first)&.content_type&.split('/')

          return [] if file_types.blank?

          tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: property_definition&.dig('tree_label'))

          Array.wrap(tree_label&.create_classification_alias(*file_types)&.primary_classification&.id)
        end

        def self.color_space_classification(property_parameters:, property_definition:, **_args)
          color_space = DataCycleCore::Asset.find_by(id: property_parameters&.first)&.metadata&.dig('colorspace')

          return [] if color_space.blank?

          tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: property_definition&.dig('tree_label'))

          Array.wrap(tree_label&.create_classification_alias(color_space)&.primary_classification&.id)
        end
      end
    end
  end
end
