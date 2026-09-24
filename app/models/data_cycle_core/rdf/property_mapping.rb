# frozen_string_literal: true

require 'rdf'

module DataCycleCore
  module Rdf
    # Shared mapping from a dataCycle property definition to its RDF range, plus the
    # required/cardinality signals. Used by both PropertyBuilder (ontology domain/range)
    # and ShapesBuilder (SHACL sh:datatype/sh:class/sh:minCount/sh:maxCount) so the two
    # never drift. Mirrors OpenApi::EntityBuilder#map_property (same source of truth).
    module PropertyMapping
      module_function

      # Property types that the v4 API delivers as arrays (no sh:maxCount 1).
      ARRAY_TYPES = ['linked', 'embedded', 'classification', 'schedule', 'opening_time', 'collection', 'table', 'timeseries'].freeze

      # [kind, ranges] for a definition. kind is :datatype or :object; ranges is an
      # array of RDF::URI (empty when there is no clean RDF range). Transformed
      # properties (nest/merge_object collapse siblings into a container, append merges
      # into one array) are objects; everything else maps by its type.
      def range_for(definition)
        api_def = DataCycleCore::OpenApi::PropertyFilter.api_definition(definition)

        case api_def.dig('transformation', 'method')
        when 'nest', 'merge_object'
          type = api_def.dig('transformation', 'type')
          [:object, type.present? ? [DataCycleCore::Rdf::Terms.type_uri(type)] : []]
        when 'append'
          [:object, []]
        else
          map_type(definition)
        end
      end

      # True when the property is delivered as an array (affects sh:maxCount). Besides
      # the inherently multi-valued types, an `append` transformation always collapses
      # its sources into one array — even when the source type is a scalar (string/
      # number) — so it must not get sh:maxCount 1.
      def multi_valued?(definition)
        return true if DataCycleCore::OpenApi::PropertyFilter.api_definition(definition).dig('transformation', 'method') == 'append'

        ARRAY_TYPES.include?(definition['type'])
      end

      # True when the property is validated as required (sh:minCount 1).
      def required?(definition)
        definition.dig('validations', 'required').present?
      end

      # Maps a dataCycle property type to [kind, ranges]. Mirrors EntityBuilder#map_property.
      def map_type(definition)
        case definition['type']
        when 'number' then [:datatype, [xsd[:decimal]]]
        when 'boolean' then [:datatype, [xsd[:boolean]]]
        when 'date' then [:datatype, [xsd[:date]]]
        when 'datetime' then [:datatype, [xsd[:dateTime]]]
        when 'oembed' then [:datatype, [xsd[:anyURI]]]
        when 'classification' then [:object, [skos[:Concept]]]
        when 'asset' then [:object, [schema[:MediaObject]]]
        when 'geographic' then [:object, [schema[:GeoCoordinates], schema[:GeoShape]]]
        when 'schedule' then [:object, [schema[:Schedule]]]
        when 'opening_time' then [:object, [schema[:OpeningHoursSpecification]]]
        when 'timeseries', 'collection', 'table' then [:object, []] # no single schema.org range
        when 'linked', 'embedded' then [:object, target_classes(definition)]
        else [:datatype, [xsd[:string]]] # string/text/slug/string_action and unknown -> string
        end
      end

      # dcls target classes of a linked/embedded property.
      def target_classes(definition)
        Array.wrap(definition['template_name']).map { |name| DataCycleCore::Rdf::Terms.dcls_class(name) }
      end

      # Vocabularies (shared, via Terms).
      def xsd
        DataCycleCore::Rdf::Terms.xsd
      end

      # skos: vocabulary (classification concepts).
      def skos
        DataCycleCore::Rdf::Terms.skos
      end

      # schema.org vocabulary (https, matching the v4 @context).
      def schema
        DataCycleCore::Rdf::Terms.schema
      end
    end
  end
end
