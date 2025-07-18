# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Virtual
      module String
        extend DataCycleCore::ContentHelper

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
            if content.association_cached?(:collected_classification_contents) &&
               content.collected_classification_contents.present? &&
               content.collected_classification_contents.all? { |ccc| ccc.association_cached?(:classification_alias) && ccc.classification_alias.association_cached?(:classification_alias_path) && ccc.classification_alias.association_cached?(:classification_tree_label) }
              content.collected_classification_contents
                .sort_by { |ccc| -ccc.classification_alias&.classification_alias_path&.full_path_ids&.size.to_i }
                .detect { |ccc| ccc.classification_alias&.classification_tree_label&.name == 'Lizenzen' }
                &.classification_alias
                &.uri
            elsif content.association_cached?(:collected_classification_contents) && content.collected_classification_contents.blank?
              nil
            else
              content.collected_classification_contents
                .classification_aliases
                .joins(:classification_alias_path)
                .for_tree('Lizenzen')
                .reorder(Arel.sql('ARRAY_LENGTH(classification_alias_paths.full_path_ids, 1) DESC'))
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
                type_of_information = DataCycleCore::ClassificationAlias
                  .for_tree('Informationstypen')
                  .with_internal_name(key)
                  .primary_classifications

                t.attributes = {
                  id: generate_uuid(content.id, key),
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
            content.classification_aliases
              .for_tree('ODTA - Tourenstatus')
              .first
              &.external_key
              &.include?('closed')
          end
        end
      end
    end
  end
end
