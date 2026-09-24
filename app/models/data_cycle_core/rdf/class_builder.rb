# frozen_string_literal: true

require 'rdf'

module DataCycleCore
  module Rdf
    # Emits the owl:Class for a single ThingTemplate (entity or embedded) into a graph,
    # from the type chain the v4 API delivers in the @type array (ThingTemplate#
    # api_schema_types). schema.org (or otherwise prefixed) ancestors become
    # rdfs:subClassOf; additional instance types declared via `api.type` (further
    # dcls: entries, e.g. a localized alias dcls:Angebot for dcls:Offer) are equivalent
    # types, so they become owl:equivalentClass and are themselves declared as owl:Class
    # — otherwise they would be referenced but never defined. rdfs:label is emitted for
    # every available locale, so the document is locale-independent.
    class ClassBuilder
      # @param template [DataCycleCore::ThingTemplate]
      def initialize(template)
        @template = template
      end

      # Adds the class triples to the given graph and returns it.
      def call(graph)
        owl = DataCycleCore::Rdf::Terms.owl
        graph << [class_uri, ::RDF.type, owl[:Class]]
        add_labels(graph)

        related_types.each do |token|
          uri = DataCycleCore::Rdf::Terms.type_uri(token)
          if token.to_s.start_with?('dcls:')
            graph << [class_uri, owl[:equivalentClass], uri]
            graph << [uri, ::RDF.type, owl[:Class]] # declare the alias type so nothing dangles
          else
            graph << [class_uri, DataCycleCore::Rdf::Terms.rdfs[:subClassOf], uri]
          end
        end

        graph
      end

      private

      # rdfs:label of the class per available locale (language-tagged literals), from
      # the template's translated name — one document covers every locale.
      def add_labels(graph)
        I18n.available_locales.each do |locale|
          label = I18n.with_locale(locale) { thing.translated_template_name(locale) }
          next if label.blank?

          graph << [class_uri, DataCycleCore::Rdf::Terms.rdfs[:label], ::RDF::Literal(label, language: locale)]
        end
      end

      # dcls:{Template} — the instance-owned class URI.
      def class_uri
        DataCycleCore::Rdf::Terms.dcls_class(@template.template_name)
      end

      # The template's underlying thing (label source).
      def thing
        @template.template_thing
      end

      # The related type tokens (api_schema_types) minus the template's own dcls class:
      # schema.org ancestors become rdfs:subClassOf, further dcls: entries (api.type
      # aliases) become owl:equivalentClass. Deduplicated; mapping happens in #call.
      def related_types
        own = "dcls:#{@template.template_name}"

        Array.wrap(@template.api_schema_types).reject { |type| type == own }.uniq
      end
    end
  end
end
