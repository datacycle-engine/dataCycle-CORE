# frozen_string_literal: true

module DataCycleCore
  module OpenApi
    # Builds the OpenAPI 3.1 component schema for a single ThingTemplate (entity or embedded).
    # Complex property types are referenced via $ref to the shared building blocks.
    class EntityBuilder
      # Envelope properties shared by every entity (see #47113 / v4 JSON-LD output).
      ENVELOPE = {
        '@id' => DataCycleCore::OpenApi::Schemas::SharedComponents.id_property,
        '@type' => { 'type' => 'array', 'items' => { 'type' => 'string' } }, # localized description added at runtime via #type_schema

        'dc:entityUrl' => { 'type' => 'string', 'format' => 'uri' },
        'dct:created' => { 'type' => 'string', 'format' => 'date-time' },
        'dct:modified' => { 'type' => 'string', 'format' => 'date-time' },
        'dc:touched' => { 'type' => 'string', 'format' => 'date-time' },
        'dc:multilingual' => { 'type' => 'boolean' },
        'dc:translation' => { 'type' => 'array', 'items' => { 'type' => 'string' } },
        'dc:classification' => { 'type' => 'array', 'items' => { '$ref' => '#/components/schemas/Concept' } }
      }.freeze

      # Scalar types that OpenAPI can express in the translatable oneOf wrapper.
      TRANSLATABLE_SCALAR_TYPES = ['string', 'number', 'integer', 'boolean'].freeze

      # Sanitizes a template name into a valid OpenAPI component key (no spaces etc.).
      def self.component_name(template_name)
        template_name.to_s.gsub(/[^a-zA-Z0-9._-]/, '')
      end

      # @param template [DataCycleCore::ThingTemplate]
      # @param locale [Symbol, String] locale used for localized titles
      def initialize(template, locale: I18n.default_locale)
        @template = template
        @locale = locale
      end

      # Builds the component schema Hash for the template. The set of delivered
      # properties (v4 skip rules) is owned by DataCycleCore::OpenApi::PropertyFilter,
      # the single source shared with the /schema XLSX export.
      def call
        properties = ENVELOPE.dup
        properties['@type'] = type_schema
        combined = thing.combined_property_names('v4')

        @template.schema_sorted['properties'].each do |name, definition|
          next unless DataCycleCore::OpenApi::PropertyFilter.api_property?(thing, name, definition, combined:)

          api_name = thing.api_name_for(name) || name
          add_property(properties, api_name, name, definition, api_definition(definition))
        end

        properties['additionalProperty'] = { 'type' => 'array', 'items' => ref('PropertyValue') } if combined.any?

        alias_sd_license_as_license(properties)

        # Renderer-injected top-level fields delivered on request (fields/include):
        # `identifier` (external syncs, _external.jb) and `dc:slugifiedName`
        # (_slugified_name.jb). ||= so a template's own property of the same name wins.
        properties['identifier'] ||= { 'type' => 'array', 'items' => ref('PropertyValue') }
        properties['dc:slugifiedName'] ||= DataCycleCore::OpenApi::Schemas::SharedComponents.translatable_value

        {
          'type' => 'object',
          'title' => @template.template_name,
          'properties' => properties,
          # v4 omits blank values entirely, so only the identifiers are guaranteed
          'required' => ['@id', '@type']
        }
      end

      private

      # _string_sd_license.jb writes the sd_license value under a second key,
      # schema.org's `license`, wherever the content is itself the licensed work
      # (Content#sd_license_delivered_as_license?). It is the only attribute partial
      # that emits a sibling key, and #api_name_for reports only sdLicense, so
      # without this the component omits a key v4 delivers on every media and
      # CreativeWork template. ||= leaves a template's own `license` untouched.
      def alias_sd_license_as_license(properties)
        return unless thing.sd_license_delivered_as_license?

        sd_license = properties[thing.api_name_for('sd_license')]
        return if sd_license.blank?

        properties['license'] ||= sd_license
      end

      def thing
        @template.template_thing
      end

      # Concrete @type array for this template: the schema.org ancestor chain
      # plus dcls:{Template} (see Thing#api_schema_types). Falls back to the
      # generic envelope shape if the template exposes no schema types.
      def type_schema
        types = thing.api_schema_types
        return ENVELOPE['@type'].merge('description' => t('schemas.type_hierarchy')) if types.blank?

        {
          'type' => 'array',
          'items' => { 'type' => 'string', 'enum' => types },
          'description' => t('schemas.entity_type', types: types.join(', ')),
          'example' => types
        }
      end

      # Localized OpenAPI string for the builder's locale.
      def t(key, **)
        DataCycleCore::OpenApi::Translations.t(key, locale: @locale, **)
      end

      # Property definition's api config with v4 overrides merged in (see ApiHelper#api_definition).
      def api_definition(definition)
        DataCycleCore::OpenApi::PropertyFilter.api_definition(definition)
      end

      # Transformed properties (nest/merge_object/append) share one target key with other
      # properties; they are emitted once as a generic container instead of per source property.
      def add_property(properties, api_name, name, definition, api_def)
        case api_def.dig('transformation', 'method')
        when 'nest', 'merge_object'
          properties[api_name] ||= nested_schema(api_def)
        when 'append'
          # appended properties share one array key; item shape varies -> permissive items
          properties[api_name] ||= { 'type' => 'array', 'items' => {} }
        else
          properties[api_name] = merge_variants(properties[api_name], property_schema(name, definition))
        end
      end

      # Two plain properties can share one api_name (e.g. two linked properties mapped to
      # containedInPlace); for arrays the item variants are unioned instead of overwritten.
      def merge_variants(existing, schema)
        return schema if existing.nil? || existing['type'] != 'array' || schema['type'] != 'array'

        variants = [existing, schema].flat_map { |s| s.dig('items', 'oneOf') || [s['items']] }.compact.uniq
        schema.merge('items' => variants.one? ? variants.first : { 'oneOf' => variants })
      end

      # Container schema for nested properties, e.g. longitude/latitude -> geo (GeoCoordinates).
      def nested_schema(api_def)
        type = api_def.dig('transformation', 'type')
        return ref(type) if DataCycleCore::OpenApi::Schemas::SharedComponents::NAMES.include?(type)

        { 'type' => 'object' }
      end

      # Full schema fragment for one property: type mapping plus localized title/description.
      # Sibling keys next to $ref are valid in OpenAPI 3.1 (JSON Schema 2020-12).
      def property_schema(name, definition)
        schema = map_property(definition)
        schema = translatable_value(schema) if translatable?(definition, schema)
        schema = schema.merge('title' => label_for(name, definition))
        description = thing.translated_helper_text(name, @locale)
        schema['description'] = description if description.present?
        schema
      end

      # A property is delivered as a translatable value (scalar in the requested
      # locale, or an array of { @language, @value } when expanded) when it is
      # stored per-locale. Embedded objects (type 'object') are translated via
      # their own nested schema, not via this scalar wrapper.
      def translatable?(definition, mapped)
        definition['storage_location'] == 'translated_value' &&
          definition['type'] != 'object' &&
          mapped['type'].is_a?(String) &&
          TRANSLATABLE_SCALAR_TYPES.include?(mapped['type'])
      end

      # Wraps a scalar fragment in the shared translatable oneOf shape, preserving
      # sibling keywords like `format` on the scalar branch.
      def translatable_value(scalar)
        opts = scalar.except('type').transform_keys(&:to_sym)
        DataCycleCore::OpenApi::Schemas::SharedComponents.translatable_value(scalar_type: scalar['type'], **opts)
      end

      # Reference to a shared component schema.
      def ref(name)
        { '$ref' => "#/components/schemas/#{name}" }
      end

      # Reference to another template's component schema.
      def template_ref(template_name)
        ref(self.class.component_name(template_name))
      end

      # Maps a dataCycle property definition to an OpenAPI 3.1 schema fragment.
      # Source of truth for edge cases: app/views/data_cycle_core/api/v4/api_base/attributes/*.jb
      def map_property(definition)
        case definition['type']
        when 'number' then { 'type' => 'number' }
        when 'boolean' then { 'type' => 'boolean' }
        when 'date' then { 'type' => 'string', 'format' => 'date' }
        when 'datetime' then { 'type' => 'string', 'format' => 'date-time' }
        when 'oembed' then { 'type' => 'string', 'format' => 'uri' }
        when 'classification' then { 'type' => 'array', 'items' => ref('Concept') }
        when 'asset' then ref('AssetReference')
        when 'geographic' then { 'oneOf' => [ref('GeoCoordinates'), ref('GeoShape')] }
        when 'schedule' then { 'type' => 'array', 'items' => ref('Schedule') }
        when 'opening_time' then { 'type' => 'array', 'items' => ref('OpeningHoursSpecification') }
        when 'timeseries' then ref('TimeseriesReference')
        when 'collection', 'table' then { 'type' => 'array', 'items' => ref('CollectionReference') }
        when 'linked' then linked_schema(definition)
        when 'embedded' then embedded_schema(definition)
        else { 'type' => 'string' } # string/text/key/slug/string_action and unknown types -> plain string
        end
      end

      # linked: array of stubs ({@id,@type}) or full target entities via include/fields.
      def linked_schema(definition)
        targets = Array.wrap(definition['template_name']).map { |t| template_ref(t) }
        { 'type' => 'array', 'items' => { 'oneOf' => [ref('EntityReference'), *targets] } }
      end

      # embedded: array of nested objects. Recursion-safe because we reference the
      # component name by $ref instead of expanding the nested schema.
      def embedded_schema(definition)
        targets = Array.wrap(definition['template_name']).map { |t| template_ref(t) }
        items =
          if targets.one?
            targets.first
          elsif targets.any?
            { 'oneOf' => targets }
          else
            { 'type' => 'object' }
          end
        { 'type' => 'array', 'items' => items }
      end

      # Localized label for a property (falls back to the raw label / key).
      def label_for(name, definition)
        DataCycleCore::Thing.human_attribute_name(
          name, base: thing, definition:, locale: @locale
        ).presence || definition['label'].presence || name.to_s
      end
    end
  end
end
