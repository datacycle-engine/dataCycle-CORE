# frozen_string_literal: true

module DataCycleCore
  module Rdf
    # Builds the standalone JSON-LD @context document served at /api/config/rdf/context.
    # Offered as its own endpoint so clients can fetch and cache the context separately
    # while the delivered JSON-LD stays directly interpretable. The prefixes are the same
    # single source of truth as the ontology (Namespaces), which in turn mirrors the v4
    # delivery @context (ThingRendererV4.api_plain_context).
    class ContextBuilder
      # Builds the { "@context" => { prefix => uri, ... } } document as a Hash.
      def call
        { '@context' => DataCycleCore::Rdf::Namespaces.all }
      end
    end
  end
end
