# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Asset
        def self.file_type_classification(property_parameters:, property_definition:, **_args)
          file_type = DataCycleCore::Asset.find_by(id: property_parameters&.first)&.content_type&.split('/')&.last

          return [] if file_type.blank?

          Array.wrap(DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(property_definition&.dig('tree_label'), file_type))
        end

        def self.color_space_classification(property_parameters:, property_definition:, **_args)
          color_space = DataCycleCore::Asset.find_by(id: property_parameters&.first)&.metadata&.dig('colorspace')

          return [] if color_space.blank?

          Array.wrap(DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(property_definition&.dig('tree_label'), color_space))
        end
      end
    end
  end
end
