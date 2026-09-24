# frozen_string_literal: true

require 'rdf'

module DataCycleCore
  module Rdf
    # Assembles the per-instance SHACL shapes (constraints/validation) as an RDF::Graph:
    # one sh:NodeShape per ThingTemplate (sh:targetClass dcls:{Template}) with one
    # sh:property shape per delivered property — sh:path, sh:datatype/sh:class (range),
    # sh:minCount for required, sh:maxCount 1 for single-valued properties. Derived from
    # the same DataDefinition source as the ontology (PropertyMapping/PropertyFilter).
    #
    # Kept separate from the RDFS/OWL ontology (OntologyBuilder) because it answers a
    # different question: the ontology describes the data model, SHACL the validation
    # rules. Property shapes are NAMED (not blank nodes) so Turtle serialization stays
    # fast even with thousands of them.
    class ShapesBuilder
      # Builds the SHACL shapes graph (one NodeShape per template). Shapes carry no
      # localized text, so there is no locale to resolve.
      def call
        DataCycleCore::ThingTemplate.all.each_with_object(::RDF::Graph.new) do |template, graph|
          add_shape(graph, template)
        end
      end

      private

      # sh:NodeShape dcls:{Template}Shape targeting dcls:{Template}, with one property
      # shape per delivered api_name. Several source properties can share an api_name
      # (e.g. merged/overlay attributes); their constraints are aggregated so the shape
      # is coherent (union of ranges, required if any source is, capped only if every
      # source is single-valued).
      def add_shape(graph, template)
        thing = template.template_thing
        shape = node_shape_uri(template.template_name)
        sh = DataCycleCore::Rdf::Terms.sh

        graph << [shape, ::RDF.type, sh[:NodeShape]]
        graph << [shape, sh[:targetClass], DataCycleCore::Rdf::Terms.dcls_class(template.template_name)]

        aggregate_properties(thing, template).each do |api_name, aggregate|
          add_property_shape(graph, shape, template.template_name, api_name, aggregate)
        end
      end

      # api_name => aggregate { ranges: [[kind, RDF::URI], …], required:, multi: } across
      # every source property that maps to it (same filter as the ontology).
      def aggregate_properties(thing, template)
        combined = thing.combined_property_names('v4')

        template.schema_sorted['properties'].each_with_object({}) do |(name, definition), aggregated|
          next unless DataCycleCore::OpenApi::PropertyFilter.api_property?(thing, name, definition, combined:)

          api_name = thing.api_name_for(name) || name
          kind, ranges = DataCycleCore::Rdf::PropertyMapping.range_for(definition)
          aggregate = (aggregated[api_name] ||= { ranges: [], required: false, multi: false })
          ranges.each { |range| aggregate[:ranges] << [kind, range] }
          aggregate[:required] ||= DataCycleCore::Rdf::PropertyMapping.required?(definition)
          aggregate[:multi] ||= DataCycleCore::Rdf::PropertyMapping.multi_valued?(definition)
        end
      end

      # A named sh:PropertyShape for one aggregated api_name.
      def add_property_shape(graph, shape, template_name, api_name, aggregate)
        property_shape = property_shape_uri(template_name, api_name)
        sh = DataCycleCore::Rdf::Terms.sh

        graph << [shape, sh[:property], property_shape]
        graph << [property_shape, ::RDF.type, sh[:PropertyShape]]
        # sh:path is the predicate as actually delivered in the JSON-LD (schema.org / dc /
        # dcls per the @context), so the shape validates the ABox — not the ontology's
        # dcls: property URI, which the delivered data never uses.
        graph << [property_shape, sh[:path], DataCycleCore::Rdf::Terms.delivered_property_uri(api_name)]

        add_range_constraint(graph, property_shape, aggregate[:ranges].uniq)

        graph << [property_shape, sh[:minCount], ::RDF::Literal(1)] if aggregate[:required]
        graph << [property_shape, sh[:maxCount], ::RDF::Literal(1)] unless aggregate[:multi]
      end

      # The value constraint, as [sh:predicate, object] "atoms": one atom is emitted
      # directly, several become sh:or ( [sh:… A] [sh:… B] ). Each range expands to the
      # form(s) v4 actually delivers (see #range_atoms), so a single nominal range can
      # already yield an sh:or (e.g. a string delivered as xsd:string / rdf:langString).
      def add_range_constraint(graph, property_shape, ranges)
        atoms = ranges.flat_map { |kind, uri| range_atoms(kind, uri) }.uniq
        return if atoms.empty?

        if atoms.one?
          predicate, object = atoms.first
          graph << [property_shape, predicate, object]
        else
          alternatives = atoms.map do |alt_predicate, alt_object|
            alt = ::RDF::Node.new
            graph << [alt, alt_predicate, alt_object]
            alt
          end
          list = ::RDF::List.new(graph:, values: alternatives)
          graph << [property_shape, DataCycleCore::Rdf::Terms.sh[:or], list.subject]
        end
      end

      # The [sh:predicate, object] atoms a single range allows. An object range is one
      # sh:class atom (delivered class IRI). A datatype range expands to the datatype(s)/
      # node kind v4 emits for that nominal type — the delivered JSON-LD diverges from
      # the nominal xsd type (translatable strings are rdf:langString, numbers arrive as
      # xsd:integer, dates as schema:Date, url-valued strings as IRIs).
      def range_atoms(kind, uri)
        sh = DataCycleCore::Rdf::Terms.sh
        return [[sh[:class], DataCycleCore::Rdf::Terms.delivered_class_uri(uri)]] if kind == :object

        delivered_datatype_atoms(uri)
      end

      # Maps a nominal xsd datatype to the sh:datatype / sh:nodeKind atoms that match the
      # values v4 serializes for it. Kept lenient on purpose: the goal is that a valid
      # instance export conforms, not to re-assert the nominal type the ontology already
      # documents.
      def delivered_datatype_atoms(xsd_uri)
        sh = DataCycleCore::Rdf::Terms.sh
        xsd = DataCycleCore::Rdf::Terms.xsd

        case xsd_uri.to_s
        when xsd[:string].to_s, xsd[:anyURI].to_s
          # Strings arrive as a plain literal, a language-tagged literal (rdf:langString)
          # or — for url-valued strings — an IRI. sh:nodeKind sh:IRIOrLiteral covers all
          # three in ONE triple; enumerating them as an sh:or would add blank-node lists
          # (there is a string on almost every template) and make Turtle/RDF-XML
          # serialization superlinearly slow.
          [[sh[:nodeKind], sh[:IRIOrLiteral]]]
        when xsd[:decimal].to_s
          [[sh[:datatype], xsd[:decimal]], [sh[:datatype], xsd[:integer]]]
        when xsd[:date].to_s, xsd[:dateTime].to_s
          [[sh[:datatype], DataCycleCore::Rdf::Terms.delivered_class_uri(DataCycleCore::Rdf::Terms.schema[:Date])]]
        else
          [[sh[:datatype], xsd_uri]]
        end
      end

      # dcls:{Template}Shape
      def node_shape_uri(template_name)
        DataCycleCore::Rdf::Namespaces.dcls["#{DataCycleCore::Rdf::Terms.sanitize(template_name)}Shape"]
      end

      # dcls:{Template}Shape-{apiName} (hyphen avoids Turtle's dot-escaping in QNames).
      def property_shape_uri(template_name, api_name)
        DataCycleCore::Rdf::Namespaces.dcls["#{DataCycleCore::Rdf::Terms.sanitize(template_name)}Shape-#{DataCycleCore::Rdf::Terms.sanitize(api_name)}"]
      end
    end
  end
end
