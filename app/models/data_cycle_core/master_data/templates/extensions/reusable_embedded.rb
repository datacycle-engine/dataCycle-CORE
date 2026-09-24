# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      module Extensions
        # Feature::ReusableEmbedded reads its flag from every embedded template, so enabling the
        # feature adds the attribute here instead of a mixin in each template definition. A template
        # defining the key itself keeps its own definition.
        module ReusableEmbedded
          # edit only: the detail view would otherwise show "Wiederverwendbar: Nein" on every embedded
          # saved once, since the checkbox submits false
          REUSABLE_PROP = {
            label: 'Wiederverwendbar',
            type: 'boolean',
            storage_location: 'value',
            visible: ['edit']
          }.freeze

          # Legacy overlay templates stay out: they may only carry their original's properties
          # (TemplateValidator#validate_overlay_properties), and an overlay is nothing to link elsewhere.
          #
          # @param templates [Array<Hash>] every transformed template, as TemplateImporter holds them
          # @return [void]
          def self.append_reusable_props!(templates)
            return unless DataCycleCore::Feature::ReusableEmbedded.enabled?

            key = DataCycleCore::Feature::ReusableEmbedded.primary_attribute_key
            overlays = Overlay.legacy_overlay_names(templates)

            templates.each do |template|
              next unless template.dig(:data, :content_type) == 'embedded' && overlays.exclude?(template[:name])

              template[:data][:properties][key] ||= REUSABLE_PROP.deep_dup
            end
          end
        end
      end
    end
  end
end
