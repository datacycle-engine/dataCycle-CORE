# frozen_string_literal: true

module DataCycleCore
  module Utility
    module DefaultValue
      module Asset
        def self.file_type_classification(property_parameters:, property_definition:, content:, **_args)
          file_types = DataCycleCore::Asset.find_by(id: property_parameters&.first)&.content_type&.split('/') ||
                       content.try(:asset)&.content_type&.split('/') ||
                       content.try(:file_format)&.split('/')

          return [] if file_types.blank?

          tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: property_definition&.dig('tree_label'))

          Array.wrap(tree_label&.create_classification_alias(*Array.wrap(file_types))&.primary_classification&.id)
        end

        def self.color_space_classification(property_parameters:, property_definition:, **_args)
          color_space = DataCycleCore::Asset.find_by(id: property_parameters&.first)&.metadata&.dig('colorspace')

          return [] if color_space.blank?

          tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: property_definition&.dig('tree_label'))

          Array.wrap(tree_label&.create_classification_alias(color_space)&.primary_classification&.id)
        end

        def self.exif_to_classification(property_parameters:, property_definition:, **_args)
          meta_data = DataCycleCore::Asset.find_by(id: property_parameters&.first)&.metadata
          meta_property_keys = property_definition.dig('default_value', 'parameters', '1', 'metadata')
          create_or_map = property_definition.dig('default_value', 'parameters', '2', 'create') || false
          return if meta_data.blank? || meta_property_keys.blank?

          search_values = meta_property_keys.map { |attribute| meta_data.dig(attribute) }&.flatten&.reject(&:blank?)&.uniq
          return if search_values.blank?

          if create_or_map
            tree_label = DataCycleCore::ClassificationTreeLabel.find_by(name: property_definition&.dig('tree_label'))
            classification_ids = []
            search_values.each do |val|
              classification_ids << tree_label&.create_classification_alias(val)&.primary_classification&.id
            end
            classification_ids
          else
            DataCycleCore::ClassificationAlias.classifications_for_tree_with_name(property_definition&.dig('tree_label'), search_values)
          end
        end

        def self.filename_to_string(property_parameters:, **_args)
          DataCycleCore::Asset.find_by(id: property_parameters&.first)&.name
        end

        def self.exif_to_string(property_parameters:, property_definition:, **_args)
          meta_data = DataCycleCore::Asset.find_by(id: property_parameters&.first)&.metadata
          meta_property_keys = property_definition.dig('default_value', 'parameters', '1', 'metadata')

          return if meta_data.blank? || meta_property_keys.blank?

          value = meta_data.dig(meta_property_keys.detect { |attribute| meta_data.dig(attribute).present? })
          value = value.is_a?(Array) ? value.join(', ') : value
          value
        end

        def self.exif_to_headline(property_parameters:, property_definition:, **_args)
          headline = exif_to_string(property_parameters: property_parameters, property_definition: property_definition)
          return headline if headline.present?

          filename_to_string(property_parameters: property_parameters)
        end

        def self.exif_to_linked(property_parameters:, property_definition:, **_args)
          meta_data = DataCycleCore::Asset.find_by(id: property_parameters&.first)&.metadata
          meta_property_keys = property_definition.dig('default_value', 'parameters', '1', 'metadata')

          return if meta_data.blank? || meta_property_keys.blank?

          meta_property_keys.each do |meta_key|
            search_value = meta_data.dig(meta_key)

            next if search_value.blank?
            search_value = search_value.join(', ') if search_value.is_a?(Array)

            stored_filter = DataCycleCore::StoredFilter.new.parameters_from_hash(property_definition.dig('stored_filter'))
            query = stored_filter.apply
            query = query.equals_translated_name(search_value)

            return Array.wrap(query.first.id) if query.first.present?
          end
          nil
        end
      end
    end
  end
end
