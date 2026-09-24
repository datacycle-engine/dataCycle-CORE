# frozen_string_literal: true

require 'rdf'

module DataCycleCore
  module Rdf
    # Assembles the per-instance RDFS/OWL ontology (TBox) as an RDF::Graph: an
    # owl:Ontology header plus one owl:Class per ThingTemplate and one property per
    # DataDefinition property. Single source of truth is the same ThingTemplate
    # structure as the OpenAPI components (#50131); this only changes the target
    # representation. SHACL constraints live in a separate document (ShapesBuilder).
    class OntologyBuilder
      # Builds the ontology graph. Labels/comments are emitted as language-tagged
      # literals for every available locale, so a single document covers all locales —
      # there is no locale argument.
      def call
        graph = ::RDF::Graph.new
        add_ontology_header(graph)

        # Classes: one owl:Class per template. each_with_object (not .each) mirrors
        # OpenApi::DocumentBuilder and avoids Rails/FindEach, whose batched ordering
        # does not fit this full-set build.
        DataCycleCore::ThingTemplate.all.each_with_object(graph) do |template, current|
          DataCycleCore::Rdf::ClassBuilder.new(template).call(current)
        end

        # Properties: aggregated globally across all templates (a property api_name is
        # usually shared), so this runs once rather than per template.
        DataCycleCore::Rdf::PropertyBuilder.new.call(graph)

        graph
      end

      private

      # The ontology resource itself: the instance-specific dcls namespace IRI carries
      # the ontology metadata (title/comment/version). All predicate URIs are built from
      # the shared Namespaces map so they are byte-identical to the v4 delivery @context.
      def add_ontology_header(graph)
        ontology = ::RDF::URI(DataCycleCore::Rdf::Namespaces.all.fetch('dcls'))
        owl = DataCycleCore::Rdf::Terms.owl
        rdfs = DataCycleCore::Rdf::Terms.rdfs
        dct = DataCycleCore::Rdf::Terms.dct

        graph << [ontology, ::RDF.type, owl[:Ontology]]
        graph << [ontology, owl[:versionInfo], ::RDF::Literal('4')]

        I18n.available_locales.each do |locale|
          graph << [ontology, dct[:title], ::RDF::Literal(t('title', locale), language: locale)]
          graph << [ontology, rdfs[:comment], ::RDF::Literal(t('comment', locale), language: locale)]
        end
      end

      # Localized ontology-level text (rdf.* namespace, config/locales/rdf.*.yml).
      def t(key, locale)
        I18n.t("rdf.ontology.#{key}", locale:, default: key.to_s.humanize)
      end
    end
  end
end
