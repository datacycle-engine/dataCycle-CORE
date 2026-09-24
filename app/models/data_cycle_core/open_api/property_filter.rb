# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    # Single source for the two v4 "which properties count?" questions, so the
    # rules never drift between the OpenAPI component schemas and the /schema UI.
    #
    # Two levels, because they answer different questions:
    #   * api_property? — is this a NAMED property in components/schemas? (strict;
    #     used by EntityBuilder). Classifications without a custom partial and
    #     combined properties are excluded here because the component folds them
    #     into the envelope's dc:classification / additionalProperty.
    #   * documented?   — does this produce ANY v4 output at all? (broad; used by
    #     the /schema XLSX export). Only truly hidden properties are excluded:
    #     internal attributes, api-disabled, the internal key (delivered as @id)
    #     and overlay variants whose base carries the api name. Classifications
    #     and combined stay, because the API still delivers them (aggregated) and
    #     the export documents them.
    #
    # Skip rules mirror the v4 renderer's *hiding* rules (_content_details.jb /
    # _content_properties.jb). The renderer additionally omits `optional`
    # properties unless explicitly requested via fields/include; those are still
    # deliverable, so they are intentionally documented (as non-required) rather
    # than skipped here.
    module PropertyFilter
      module_function

      # @param content    [DataCycleCore::Thing] the template thing owning the property
      # @param name       [String] the raw property key
      # @param definition [Hash]   the raw property definition
      # @param combined   [Array<String>] content.combined_property_names('v4')
      # @return [Boolean] true when the property is a named component property
      def api_property?(content, name, definition, combined:)
        return false unless documented?(name, definition, content.schema&.dig('properties'))
        return false if definition['type'] == 'classification' && api_definition(definition)['partial'].blank?
        return false if combined.include?(name)

        api_name = content.api_name_for(name, definition) || name
        !DataCycleCore::OpenApi::EntityBuilder::ENVELOPE.key?(api_name) # envelope definitions win (e.g. properties mapped to @type)
      end

      # @param name       [String] the raw property key
      # @param definition [Hash]   the raw property definition
      # @param siblings   [Hash, nil] the properties hash +name+ belongs to, used to
      #   resolve an overlay variant against its base. nil where no sibling map is at
      #   hand, which can only make an overlay variant read as redundant.
      # @return [Boolean] true when the property produces some v4 output (worth
      #   documenting) — not hidden outright.
      def documented?(name, definition, siblings = nil)
        # ordered_api_properties drops these before rendering, so no template
        # property named date_created/date_modified/date_deleted/is_part_of/id is
        # ever delivered — the timestamps ship as the envelope's dct:created and
        # dct:modified instead.
        return false if DataCycleCore::DataHashHelper::INTERNAL_PROPERTIES.include?(name)
        return false unless renderable?(definition)

        overlay_for = definition.dig('features', 'overlay', 'overlay_for')
        return true if overlay_for.blank?

        # An overlay variant is delivered under its base's api name, so normally the
        # base documents it and the variant is redundant. Where the base is hidden
        # (aggregate templates disable it, leaving `<name>_overlay` the only enabled
        # carrier), skipping both would drop a key the API does deliver — e.g. every
        # aggregate's `name`, `address` and `image`.
        base = siblings&.dig(overlay_for)
        base.present? && !renderable?(base)
      end

      # @param definition [Hash] the raw property definition
      # @return [Boolean] true when the v4 renderer emits this property at all,
      #   before overlay resolution decides which variant owns the api name.
      def renderable?(definition)
        return false if api_definition(definition)['disabled']
        return false if definition['type'] == 'key' # the identifier is exposed via the @id envelope property

        true
      end

      # Property definition's api config with v4 overrides merged in
      # (see ApiHelper#api_definition).
      def api_definition(definition)
        api = definition['api'] || {}
        api.reject { |k, _v| k.to_s.match?(/\Av\d+\z/) }.merge(api['v4'] || {})
      end
    end
  end
end
