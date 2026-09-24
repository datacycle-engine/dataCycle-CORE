# frozen_string_literal: true

module DataCycleCore
  module Mcp
    # Which attributes of a template are writable from outside -- the single source of this
    # whitelist, shared by Mcp::ContentWriter (which slices against it) and
    # Tools::ListWritableAttributes (which ships it). Without this discovery, writing over MCP was
    # practically unusable: get_schema and list_attributes return the API NAMES of the v4 API
    # (`odta:length`, `odta:uphillElevation`), while writing goes through the internal property
    # names (`length`, `ascent`) -- the API names land silently in ignored_attributes. Every entry
    # here therefore carries BOTH names, and #suggestions_for translates a rejected API name back
    # into the writable key.
    class WritableAttributes
      # locale: only for the labels of the discovery list (#to_a). The whitelist itself (#names) and
      # the name correction are language-independent, so the writer passes none.
      def initialize(content, locale: I18n.locale)
        @content = content
        @locale = locale
      end

      # Whitelist: only attributes an importer is allowed to set as well.
      # IMPORTABLE_INTERNAL_PROPERTY_NAMES (id, external_key, external_system_data) are deliberately
      # excluded: an id set by the LLM would turn a create into an overwrite of arbitrary records,
      # and an external_key assigns the record to an import source that overwrites it on its next
      # run.
      def names
        @names ||= @content.importable_property_names - DataCycleCore::Content::Content::IMPORTABLE_INTERNAL_PROPERTY_NAMES
      end

      # Discovery list for list_writable_attributes.
      def to_a
        names.sort.map { |name| describe(name) }
      end

      # Translates passed, non-writable keys back where they are recognisable as the API name of a
      # writable attribute: { 'odta:length' => 'length' }.
      def suggestions_for(rejected_names)
        reverse = api_names.invert

        Array.wrap(rejected_names).filter_map { |name|
          suggestion = reverse[name.to_s] || reverse[name.to_s.downcase]
          [name, suggestion] if suggestion.present?
        }.to_h
      end

      private

      def describe(name)
        definition = @content.property_definitions[name] || {}

        {
          attribute: name,
          api_name: api_names[name],
          type: definition['type'],
          label: label_for(name, definition),
          unit: definition.dig('api', 'unit_text') || definition.dig('api', 'unit_code'),
          concept_scheme: definition['tree_label'],
          embedded_template: definition['template_name'],
          translatable: name.in?(@content.translatable_property_names).presence,
          required: definition.dig('validations', 'required').presence,
          recommended: definition.dig('validations', 'soft_required').presence
        }.compact
      end

      # The resolved label, not the raw one from the template definition: a label there can also be
      # an i18n key hash ({ key:, key_suffix: }) whose resolution needs a content instance as :base
      # -- which exists here (unlike in Mcp::AttributeFilter, where the discovery runs without an
      # instance and hash labels therefore have to be dropped).
      #
      # And it is needed: `unit` is only present on attributes with api.unit_text/unit_code; on all
      # others the label is the only statement of the unit ("Duration (min)"). A discarded label
      # therefore means a client sees neither a unit nor a hint and writes hours into a minutes
      # field. Side effect: the label now comes in the requested language rather than in whichever
      # language it happens to sit in in the YAML.
      #
      # locale_string: false, because the language marker ("Title (de)") belongs to the UI -- here
      # the `translatable` field states an attribute's language behaviour.
      def label_for(name, definition)
        DataCycleCore::Thing.human_attribute_name(name, { base: @content, definition:, locale: @locale, locale_string: false }).presence
      end

      # Internal property name -> API name, from the same materialized view list_attributes takes
      # its names from (nested paths such as address.x excluded).
      def api_names
        @api_names ||= DataCycleCore::ContentProperties
          .where(template_name: @content.template_name)
          .where.not(api_name: nil)
          .pluck(:property_name, :api_name)
          .reject { |property_name, _api_name| property_name.include?('.') }
          .to_h
      end
    end
  end
end
