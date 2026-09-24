# frozen_string_literal: true

require 'rdf'

module DataCycleCore
  module Rdf
    # Emits the ontology's properties. RDF properties have global identity, so a
    # property api_name shared by many templates (e.g. dateCreated is on all of them)
    # becomes ONE dcls:{apiName} with its domain/range aggregated across every template
    # that uses it — a single rdfs:domain/rdfs:range when unambiguous, else the flat
    # schema:domainIncludes/schema:rangeIncludes pattern (see #emit_relation).
    #
    # The type mapping mirrors OpenApi::EntityBuilder#map_property (same single source
    # of truth, #50131); only the target changes from JSON Schema to RDFS/OWL ranges.
    # api_name resolution, the v4 skip rules and transformation handling are reused from
    # PropertyFilter so the two representations never drift.
    class PropertyBuilder
      def initialize
        @properties = {} # api_name => { kinds: Set, domains: Set<RDF::URI>, ranges: Set<RDF::URI>, labels:, comments: }
      end

      # Aggregates every template's api-properties, then writes one property per api_name.
      def call(graph)
        collect
        emit(graph)
        graph
      end

      private

      # Walks all templates and records each delivered property's class + range.
      def collect
        DataCycleCore::ThingTemplate.all.each_with_object(@properties) do |template, _acc|
          collect_template(template)
        end
      end

      # Records the api-properties of one template (same filter/skip rules as the
      # OpenAPI component builder).
      def collect_template(template)
        thing = template.template_thing
        class_uri = DataCycleCore::Rdf::Terms.dcls_class(template.template_name)
        combined = thing.combined_property_names('v4')

        template.schema_sorted['properties'].each do |name, definition|
          next unless DataCycleCore::OpenApi::PropertyFilter.api_property?(thing, name, definition, combined:)

          api_name = thing.api_name_for(name) || name
          kind, ranges = DataCycleCore::Rdf::PropertyMapping.range_for(definition)
          register(api_name, class_uri, kind, ranges)
          collect_texts(api_name, thing, name, definition)
        end
      end

      # Merges one occurrence into the aggregated entry for its api_name.
      def register(api_name, class_uri, kind, ranges)
        entry = entry_for(api_name)
        entry[:kinds] << kind
        entry[:domains] << class_uri
        ranges.each { |range| entry[:ranges] << range }
      end

      # Records the first non-blank rdfs:label/rdfs:comment per available locale for the
      # property. A shared api_name usually labels identically across templates; the
      # first occurrence wins so the property carries one label per language.
      def collect_texts(api_name, thing, name, definition)
        entry = entry_for(api_name)

        I18n.available_locales.each do |locale|
          entry[:labels][locale] ||= label_for(thing, name, definition, locale)
          entry[:comments][locale] ||= comment_for(thing, name, locale)
        end
      end

      # The aggregated entry for an api_name (created on first use).
      def entry_for(api_name)
        @properties[api_name] ||= { kinds: Set.new, domains: Set.new, ranges: Set.new, labels: {}, comments: {} }
      end

      # Localized property label without the "(locale)" translatable suffix.
      def label_for(thing, name, definition, locale)
        I18n.with_locale(locale) do
          DataCycleCore::Thing.human_attribute_name(name, base: thing, definition:, locale:, locale_string: false).presence
        end
      end

      # Localized helper text (tooltip) used as rdfs:comment, if any.
      def comment_for(thing, name, locale)
        I18n.with_locale(locale) { thing.translated_helper_text(name, locale) }.presence
      end

      # Writes one property definition per aggregated api_name.
      def emit(graph)
        rdfs = DataCycleCore::Rdf::Terms.rdfs
        schema = DataCycleCore::Rdf::Terms.schema

        @properties.each do |api_name, entry|
          property = DataCycleCore::Rdf::Terms.dcls_property(api_name)

          graph << [property, ::RDF.type, property_type(entry[:kinds])]
          graph << [property, rdfs[:subPropertyOf], schema[DataCycleCore::Rdf::Terms.sanitize(api_name)]] if DataCycleCore::Rdf::Terms.schema_property?(api_name)

          emit_relation(graph, property, rdfs[:domain], schema[:domainIncludes], entry[:domains])
          emit_relation(graph, property, rdfs[:range], schema[:rangeIncludes], entry[:ranges])

          add_texts(graph, property, entry, rdfs)
        end
      end

      # A single value uses rdfs:domain / rdfs:range (one triple). Several values use
      # schema:domainIncludes / schema:rangeIncludes — flat multi-triples, no blank
      # nodes. This is schema.org's own pattern for multi-type properties: it avoids
      # both the rdfs intersection semantics of repeated rdfs:domain and the
      # owl:unionOf blank-node lists (whose huge lists made Turtle serialization
      # pathologically slow). Empty sets emit nothing.
      def emit_relation(graph, property, rdfs_predicate, includes_predicate, uris)
        list = uris.to_a
        return if list.empty?

        if list.one?
          graph << [property, rdfs_predicate, list.first]
        else
          list.each { |uri| graph << [property, includes_predicate, uri] }
        end
      end

      # rdfs:label / rdfs:comment as language-tagged literals (one per locale).
      def add_texts(graph, property, entry, rdfs)
        entry[:labels].each do |locale, value|
          graph << [property, rdfs[:label], ::RDF::Literal(value, language: locale)] if value.present?
        end
        entry[:comments].each do |locale, value|
          graph << [property, rdfs[:comment], ::RDF::Literal(value, language: locale)] if value.present?
        end
      end

      # owl:DatatypeProperty / owl:ObjectProperty when unambiguous, else rdf:Property
      # (a property seen as both literal- and resource-valued across templates).
      def property_type(kinds)
        return DataCycleCore::Rdf::Terms.owl[:DatatypeProperty] if kinds == Set[:datatype]
        return DataCycleCore::Rdf::Terms.owl[:ObjectProperty] if kinds == Set[:object]

        DataCycleCore::Rdf::Terms.rdf[:Property]
      end
    end
  end
end
