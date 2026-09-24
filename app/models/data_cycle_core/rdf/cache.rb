# frozen_string_literal: true

require 'rdf'

module DataCycleCore
  module Rdf
    # Caches the generated RDF documents. Building a graph from every ThingTemplate and
    # serializing it is not free, so results are memoized in Rails.cache keyed on a
    # fingerprint of the template set (newest updated_at + count). Any template change,
    # addition or removal changes the fingerprint and therefore invalidates the cache
    # automatically (#50196, caching and invalidation on template changes).
    #
    # Two levels so a single build serves every format: the built graph is cached once
    # per kind (as N-Triples, cheap to reparse), and each format's serialized string is
    # cached on top. The document is locale-independent — labels/comments for every
    # available locale are emitted into one graph — so locale is not part of the key.
    module Cache
      module_function

      # Serialized RDF document for a kind (:ontology/:shapes) and writer format.
      def document(kind, format)
        Rails.cache.fetch(document_key(kind, format), expires_in: 1.week) do
          DataCycleCore::Rdf::Serializer.serialize(graph(kind), format:)
        end
      end

      # The built graph for a kind, reparsed from its cached N-Triples blob so the
      # (repeated) full build runs at most once per template-set version.
      def graph(kind)
        blob = Rails.cache.fetch(graph_key(kind), expires_in: 1.week) do
          DataCycleCore::Rdf::Serializer.serialize(build(kind), format: :ntriples)
        end
        parse(blob)
      end

      # Builds a fresh graph for the kind.
      def build(kind)
        builder_class(kind).new.call
      end

      # Builder for a kind.
      def builder_class(kind)
        case kind.to_sym
        when :ontology then DataCycleCore::Rdf::OntologyBuilder
        when :shapes then DataCycleCore::Rdf::ShapesBuilder
        else raise ArgumentError, "unknown RDF graph kind: #{kind}"
        end
      end

      # Parses an N-Triples blob back into a graph.
      def parse(blob)
        graph = ::RDF::Graph.new
        ::RDF::Reader.for(:ntriples).new(blob) { |reader| graph << reader }
        graph
      end

      # Cache key for a serialized document.
      def document_key(kind, format)
        "#{key_prefix(kind)}/#{format}"
      end

      # Cache key for the built graph blob.
      def graph_key(kind)
        "#{key_prefix(kind)}/graph"
      end

      # Namespaced, fingerprinted key prefix. The fingerprint (newest template
      # timestamp + count) changes on any template update/create/delete.
      def key_prefix(kind)
        fingerprint = [DataCycleCore::ThingTemplate.maximum(:updated_at).to_i, DataCycleCore::ThingTemplate.count]
        "data_cycle_core/rdf/#{kind}/#{fingerprint.join('-')}"
      end
    end
  end
end
