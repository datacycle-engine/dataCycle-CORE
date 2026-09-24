# frozen_string_literal: true

require 'rdf'
require 'rdf/turtle'
require 'rdf/rdfxml'
require 'json/ld'

module DataCycleCore
  module Rdf
    # Serializes an RDF::Graph into the formats negotiated by the RDF endpoints
    # (Turtle / JSON-LD / RDF-XML / N-Triples), always binding the shared prefix
    # map (Namespaces) so the output stays readable and consistent across formats.
    module Serializer
      module_function

      # Route/extension token => RDF.rb writer format symbol.
      FORMATS = {
        'ttl' => :turtle,
        'jsonld' => :jsonld,
        'rdf' => :rdfxml,
        'nt' => :ntriples
      }.freeze

      # Writer format symbol => response content type.
      CONTENT_TYPES = {
        turtle: 'text/turtle',
        jsonld: 'application/ld+json',
        rdfxml: 'application/rdf+xml',
        ntriples: 'application/n-triples'
      }.freeze

      # Serializes the graph to the given writer format (default Turtle). Namespaces
      # already carries the schema-language prefixes (owl/rdf/rdfs/xsd/sh), so no
      # standard_prefixes injection is needed.
      def serialize(graph, format: :turtle)
        ::RDF::Writer.for(format).buffer(**writer_options(format)) do |writer|
          writer << graph
        end
      end

      # Per-format writer options. JSON-LD gets an explicit @context (our shared prefix
      # map) instead of :prefixes: it both drives compaction and avoids a hash-mutated-
      # during-iteration bug in the json-ld writer's :prefixes path.
      def writer_options(format)
        return { context: Namespaces.all } if format == :jsonld

        { prefixes: Namespaces.rdf }
      end

      # Content type header for a writer format.
      def content_type(format)
        CONTENT_TYPES.fetch(format, CONTENT_TYPES[:turtle])
      end
    end
  end
end
