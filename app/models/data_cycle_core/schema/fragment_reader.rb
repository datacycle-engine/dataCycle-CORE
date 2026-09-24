# frozen_string_literal: true

module DataCycleCore
  class Schema
    # READS an OpenAPI 3.1 schema fragment (from components/schemas, built by
    # DataCycleCore::OpenApi::EntityBuilder) and turns it into "Expected Type"
    # descriptors for the /schema UI.
    #
    # This is a CONSUMER of the generated document, NOT a reimplementation of the
    # type mapping — there is no second source of truth (see #50201). Type,
    # cardinality and nesting all come straight out of the fragment.
    #
    # A descriptor is a Hash:
    #   { label:, kind: (semantic type -> chip colour class), href: (schema.org / external
    #     URL, optional), template: (routable :id, optional) }
    module FragmentReader
      module_function

      # Names of the shared building-block schemas (Concept, GeoCoordinates, …).
      # A $ref to one of these is a shared type; anything else is a template.
      SHARED_NAMES = DataCycleCore::OpenApi::Schemas::SharedComponents::NAMES

      # Shared components that carry a geo semantic (styled as a geo chip).
      GEO_SHARED_NAMES = ['GeoCoordinates', 'GeoShape'].freeze

      # Generic reference envelopes. EntityBuilder emits these next to the concrete
      # targets in a linked/collection oneOf (see EntityBuilder#linked_schema); once a
      # concrete descriptor is present they are redundant and get dropped.
      GENERIC_REFERENCE_NAMES = ['EntityReference', 'CollectionReference'].freeze

      # @return [:one, :many] arrays are delivered as collections.
      def cardinality(fragment)
        fragment['type'] == 'array' ? :many : :one
      end

      # @param fragment       [Hash] the property's OpenAPI schema fragment
      # @param template_index [Hash{String=>String}] component_name => routable template :id
      # @return [Array<Hash>] expected-type descriptors.
      def descriptors(fragment, template_index = {})
        node(unwrap(fragment), template_index)
      end

      # Descends into array items so the descriptors describe the delivered element.
      def unwrap(fragment)
        fragment['type'] == 'array' ? (fragment['items'] || {}) : fragment
      end

      # Interprets a single (already unwrapped) schema node.
      def node(schema, template_index)
        return [] if schema.blank?

        if schema['oneOf'].present?
          # drop the translatable language-array branch; it is signalled via the `translated` flag
          descriptors = schema['oneOf'].reject { |b| language_array?(b) }.flat_map { |b| node(unwrap(b), template_index) }.uniq
          drop_generic_references(descriptors)
        elsif schema['$ref'].present?
          [ref_descriptor(schema['$ref'], template_index)]
        elsif schema['type'].present?
          [scalar_descriptor(schema)]
        else
          []
        end
      end

      # Removes the generic reference envelope once a concrete type is present,
      # but keeps it when it is the only descriptor (so the chip never disappears).
      def drop_generic_references(descriptors)
        concrete = descriptors.reject { |d| GENERIC_REFERENCE_NAMES.include?(d[:label]) }
        concrete.presence || descriptors
      end

      # The array-of-{ @language, @value } branch of a translatable value.
      def language_array?(schema)
        schema['type'] == 'array' && schema.dig('items', 'properties')&.key?('@value')
      end

      # $ref -> descriptor. Shared component => shared type; otherwise a template link.
      # :kind is the semantic type used to pick the chip colour in the stylesheet
      # (schema-tag--type-*), so no colour ever lives in the view.
      def ref_descriptor(ref, template_index)
        name = ref.to_s.split('/').last
        return { label: 'skos:Concept', kind: :concept, href: 'https://www.w3.org/2009/08/skos-reference/skos.html#Concept' } if name == 'Concept'
        # Generic reference envelopes are shared components too, but semantically they
        # denote a LINKED entity, not a schema.org payload type. Classify them as
        # :reference (dataCycle's linked-type icon, no routable template → no 404 link)
        # BEFORE the generic shared-name branch, which would otherwise fall to the cube.
        return { label: name, kind: :reference } if GENERIC_REFERENCE_NAMES.include?(name)
        return { label: name, kind: GEO_SHARED_NAMES.include?(name) ? :geo : :shared } if SHARED_NAMES.include?(name)

        id = template_index[name] || name
        { label: id, kind: :reference, template: id }
      end

      # A scalar node (type + optional format) -> schema.org literal descriptor.
      def scalar_descriptor(schema)
        label, kind =
          case [schema['type'], schema['format']]
          when ['string', 'date-time'] then ['DateTime', :datetime]
          when ['string', 'date'] then ['Date', :date]
          when ['string', 'uri'] then ['URL', :url]
          when ['integer', nil] then ['Integer', :integer]
          else scalar_by_type(schema['type'])
          end
        { label:, kind:, href: "//schema.org/#{label}" }
      end

      # Non-formatted scalar types -> [schema.org label, chip kind].
      def scalar_by_type(type)
        case type
        when 'number' then ['Number', :number]
        when 'boolean' then ['Boolean', :boolean]
        else ['Text', :text]
        end
      end
    end
  end
end
