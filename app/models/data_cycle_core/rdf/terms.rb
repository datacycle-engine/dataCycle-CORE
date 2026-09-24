# frozen_string_literal: true

require 'rdf'
require 'rdf/vocab'
require 'json/ld'

module DataCycleCore
  module Rdf
    # Shared URI construction for the RDF builders: turns template names and the
    # schema-type tokens found in ThingTemplate#api_schema_types into absolute URIs,
    # always via the shared Namespaces prefix map so class/property/shape URIs stay
    # byte-identical to the v4 delivery @context. Also the single home for the vocabulary
    # accessors (owl/rdfs/rdf/xsd/skos/sh/dct/schema) so no builder redefines them.
    module Terms
      module_function

      # owl: vocabulary.
      def owl
        DataCycleCore::Rdf::Namespaces.vocabulary('owl')
      end

      # rdfs: vocabulary.
      def rdfs
        DataCycleCore::Rdf::Namespaces.vocabulary('rdfs')
      end

      # rdf: vocabulary.
      def rdf
        DataCycleCore::Rdf::Namespaces.vocabulary('rdf')
      end

      # xsd: vocabulary (literal datatypes).
      def xsd
        DataCycleCore::Rdf::Namespaces.vocabulary('xsd')
      end

      # skos: vocabulary (classification concepts).
      def skos
        DataCycleCore::Rdf::Namespaces.vocabulary('skos')
      end

      # sh: vocabulary (SHACL).
      def sh
        DataCycleCore::Rdf::Namespaces.vocabulary('sh')
      end

      # dct: vocabulary (Dublin Core terms).
      def dct
        DataCycleCore::Rdf::Namespaces.vocabulary('dct')
      end

      # Sanitizes a template/type name into a safe URI local name. Mirrors
      # OpenApi::EntityBuilder.component_name so RDF class names match the OpenAPI keys.
      def sanitize(name)
        name.to_s.gsub(/[^a-zA-Z0-9._-]/, '')
      end

      # Class URI for a template: dcls:{SanitizedName}.
      def dcls_class(template_name)
        DataCycleCore::Rdf::Namespaces.dcls[sanitize(template_name)]
      end

      # Property URI for an api_name: dcls:{sanitizedApiName}. Properties live in the
      # instance's own namespace (symmetric to the classes); a subPropertyOf bridge to
      # schema.org is added by PropertyBuilder whenever schema_property? is true.
      def dcls_property(api_name)
        DataCycleCore::Rdf::Namespaces.dcls[sanitize(api_name)]
      end

      # True when the (sanitized) name is a real schema.org property — used to emit
      # rdfs:subPropertyOf schema:{name}. Membership comes from rdf-vocab; the emitted
      # URI still uses our https schema: namespace from the shared prefix map.
      def schema_property?(name)
        schema_property_names.include?(sanitize(name))
      end

      # Memoized set of schema.org property local names (process-lifetime).
      def schema_property_names
        @schema_property_names ||= ::RDF::Vocab::SCHEMA.properties.to_set { |term| term.to_uri.to_s.split('/').last }
      end

      # True when the (sanitized) name is a real schema.org class. #type_uri deliberately
      # puts any unprefixed token in the schema: namespace, which is fine for an identifier
      # nobody dereferences; a link a reader clicks needs this check first, or a
      # DataCycle-only type like EVChargingStation or GtfsStop points at a 404.
      def schema_class?(name)
        schema_class_names.include?(sanitize(name))
      end

      # Memoized set of schema.org class local names (process-lifetime). rdf-vocab models
      # classes and properties as one term list, so the classes are the #class? subset.
      def schema_class_names
        @schema_class_names ||= ::RDF::Vocab::SCHEMA.each.select(&:class?).to_set { |term| term.to_uri.to_s.split('/').last }
      end

      # Resolves a schema-type token (as found in api_schema_types) to an absolute URI.
      # Unprefixed tokens are schema.org types ("Place" -> schema:Place); "prefix:Local"
      # tokens use the matching namespace from the shared prefix map, falling back to
      # schema.org for an unknown prefix.
      def type_uri(token)
        prefix, separator, local = token.to_s.rpartition(':')
        return schema[sanitize(token)] if separator.blank?

        DataCycleCore::Rdf::Namespaces.all.key?(prefix) ? DataCycleCore::Rdf::Namespaces.vocabulary(prefix)[sanitize(local)] : schema[sanitize(token)]
      end

      # The schema.org vocabulary (https://schema.org/, matching the v4 @context).
      def schema
        DataCycleCore::Rdf::Namespaces.vocabulary('schema')
      end

      # The parsed v4 delivery @context. This is the authoritative source for how an
      # api_name (a delivered JSON-LD key) expands to a predicate/class IRI in the
      # delivered data: a bare term resolves via @vocab to schema.org, a key carrying a
      # dc:/dcls: prefix (baked into the DataDefinition api.name) resolves to that
      # namespace. Built with expanded = true so @language is dropped — the default
      # locale is a Symbol, which JSON::LD::Context rejects as a language tag.
      def delivery_context
        @delivery_context ||= ::JSON::LD::Context.new.parse(
          DataCycleCore::ApiRenderer::ThingRendererV4.api_plain_context(nil, true)
        )
      end

      # The predicate IRI an api_name expands to in the delivered JSON-LD. Used for the
      # SHACL sh:path so the shapes match the delivered ABox (predicates are schema.org /
      # dc / dcls per the @context), not the ontology's own dcls: property URIs.
      def delivered_property_uri(api_name)
        ::RDF::URI(delivery_context.expand_iri(api_name.to_s, vocab: true).to_s)
      end

      # Rewrites an ontology class URI to the form the JSON-LD actually delivers in
      # @type. Only schema.org differs: the ontology uses the https URL from the @context
      # string, while schema.org's @vocab delivers http://schema.org/. dcls/dc/skos class
      # URIs already match the delivered @type, so they pass through unchanged.
      def delivered_class_uri(uri)
        prefix = schema.to_s
        return uri unless uri.to_s.start_with?(prefix)

        ::RDF::URI(delivery_context.expand_iri(uri.to_s[prefix.length..], vocab: true).to_s)
      end
    end
  end
end
