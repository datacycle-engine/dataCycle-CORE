# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module String
        EXTERNAL_SYSTEM_MAPPING = {
          'outdooractive' => 'outdoor_active'
        }.freeze

        class << self
          # :virtual:
          #   :module: String
          #   :method: concat
          #   :separator: " "
          #   :parameters:
          #     - given_name
          #     - family_name
          def concat(virtual_parameters:, virtual_definition:, content:, **)
            separator = virtual_definition['separator'] || ' '
            virtual_parameters.filter_map { |key| content.try(key)&.to_s }.join(separator)
          end

          def translation_by_imported_key(content:, virtual_parameters:, **_args)
            base_content = content.template_name == 'Übersetzung' ? content.try(:about)&.first : content
            return if base_content.nil?

            virtual_parameters.each do |item|
              external_system_key = base_content.external_source&.identifier
              external_system_key = EXTERNAL_SYSTEM_MAPPING[external_system_key] if EXTERNAL_SYSTEM_MAPPING.key?(external_system_key)
              key = content.try(item)

              return I18n.t("import.#{external_system_key}.#{base_content.template_name.downcase}.#{key}") if I18n.exists?("import.#{external_system_key}.#{base_content.template_name.downcase}.#{key}")
            end

            content.try(virtual_parameters.first)
          end

          def license_uri(content:, **_args)
            if content.association_cached?(:collected_concept_contents) &&
               content.collected_concept_contents.present? &&
               content.collected_concept_contents.all? { |ccc| ccc.association_cached?(:concept) && ccc.concept.association_cached?(:concept_path) && ccc.concept.association_cached?(:concept_scheme) }
              content.collected_concept_contents
                .reject(&:hidden) # #47172: hidden mappings are not exposed
                .sort_by { |ccc| -ccc.concept&.concept_path&.full_path_ids&.size.to_i }
                .detect { |ccc| ccc.concept&.concept_scheme&.name == 'Lizenzen' }
                &.concept
                &.uri
            elsif content.association_cached?(:collected_concept_contents) && content.collected_concept_contents.blank?
              nil
            else
              content.collected_concept_contents
                .without_hidden # #47172: hidden mappings are not exposed
                .concepts
                .joins(:concept_path)
                .for_tree('Lizenzen')
                .reorder(Arel.sql('ARRAY_LENGTH(concept_paths.full_path_ids, 1) DESC'))
                .pick(:uri)
            end
          end

          # only works for sync_api
          def to_additional_information(content:, virtual_parameters:, virtual_definition:, **_args)
            template = DataCycleCore::Thing.new(template_name: virtual_definition&.dig('template_name'))

            return if template.template_missing?

            virtual_parameters.filter_map do |key|
              value = content.try(key)

              next if value.blank?

              template.dup.tap do |t|
                type_of_information = DataCycleCore::Concept
                  .for_tree('Informationstypen')
                  .with_internal_name(key)

                t.attributes = {
                  id: DataCycleCore::UuidService.generate(content.id, key),
                  created_at: Time.zone.now,
                  updated_at: Time.zone.now,
                  name: content.properties_for(key)&.dig('label'),
                  description: content.try(key)
                }

                t.set_memoized_attribute('type_of_information', type_of_information)
              end
            end
          end

          def odta_tourenstatus_as_trail_closed(content:, **_args) # rubocop:disable Naming/PredicateMethod
            content.concepts
              .for_tree('ODTA - Tourenstatus')
              .first
              &.external_key
              &.include?('closed')
          end

          # :virtual:
          #   :module: String
          #   :method: slugify
          #   :parameters:
          #     - name
          def slugify(content:, virtual_parameters:, **_args)
            content.try(virtual_parameters.first).presence&.to_s&.to_slug
          end

          # Returns a single flat value (external_key by default) of the
          # classification selected on the content for the given tree_label.
          # Used to expose single-select classifications as a plain value in the API.
          # :virtual:
          #   :module: String
          #   :method: classification_value
          #   :tree_label: HeadlineLevels
          #   :key: external_key
          def classification_value(content:, virtual_definition:, **_args)
            tree_label = virtual_definition.dig('virtual', 'tree_label')
            return if tree_label.blank?

            key = virtual_definition.dig('virtual', 'key').presence || 'external_key'

            content.full_concepts.for_tree(tree_label).pick(key)
          end
        end
      end
    end
  end
end
