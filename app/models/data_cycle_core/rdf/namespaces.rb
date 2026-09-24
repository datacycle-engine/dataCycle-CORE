# frozen_string_literal: true

require 'rdf'

module DataCycleCore
  # RDF schema generation (RDFS/OWL ontology, SHACL shapes, JSON-LD @context) from the
  # instance's DataDefinitions / ThingTemplates. Same single source of truth as the
  # OpenAPI components (DataCycleCore::OpenApi, #50131), different target representation.
  module Rdf
    # Single source of truth for the RDF prefix/namespace map.
    #
    # The instance prefixes (dc, dcls, skos, dct, cc, odta, sdm, alps, schema) are taken
    # verbatim from the v4 JSON-LD @context (ThingRendererV4.api_plain_context) so the
    # ontology, the SHACL shapes and the delivered instance data share identical
    # namespaces (#50196: one source of truth, not a duplicate). The
    # schema-language prefixes (owl/rdf/rdfs/xsd/sh) needed to express the ontology
    # itself are layered on top.
    module Namespaces
      module_function

      # Prefixes describing the schema language itself (not part of the v4 @context).
      SCHEMA_LANGUAGE = {
        'owl' => 'http://www.w3.org/2002/07/owl#',
        'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
        'rdfs' => 'http://www.w3.org/2000/01/rdf-schema#',
        'xsd' => 'http://www.w3.org/2001/XMLSchema#',
        'sh' => 'http://www.w3.org/ns/shacl#'
      }.freeze

      # The full prefix => absolute-URI map as plain strings (JSON-LD @context friendly).
      # Memoized: the instance prefixes come from the v4 @context and are stable for the
      # process lifetime, so they are resolved once instead of on every vocabulary lookup.
      def all
        @all ||= instance_prefixes.merge(SCHEMA_LANGUAGE)
      end

      # prefix => RDF::URI, ready to feed into RDF::Graph namespaces / writer :prefixes.
      def rdf
        all.transform_values { |uri| ::RDF::URI(uri) }
      end

      # An RDF::Vocabulary::Term factory for the given prefix (e.g. dcls[:POI]), memoized.
      def vocabulary(prefix)
        vocabularies[prefix.to_s] ||= ::RDF::Vocabulary.new(all.fetch(prefix.to_s))
      end

      # Per-prefix memoized RDF::Vocabulary cache.
      def vocabularies
        @vocabularies ||= {}
      end

      # The instance-specific schema namespace (dcls:) that owns the generated classes.
      def dcls
        vocabulary('dcls')
      end

      # Prefixes taken verbatim from the v4 JSON-LD @context (single source of truth).
      # The context is [schema.org string, { @base, @language, prefix => uri, ... }];
      # @base/@language are JSON-LD keywords, not namespace prefixes, so they are dropped.
      def instance_prefixes
        context = DataCycleCore::ApiRenderer::ThingRendererV4.api_plain_context(nil, true)
        base = context.first
        prefixes = context.last

        prefixes
          .reject { |key, _value| key.to_s.start_with?('@') }
          .merge('schema' => base)
      end
    end
  end
end
