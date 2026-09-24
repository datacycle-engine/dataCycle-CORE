# frozen_string_literal: true

module DataCycleCore
  module Mcp
    module Tools
      # The model-level equivalent of Api::V4::UniversalController#show -- instead of an HTTP
      # redirect to the type-specific route, the tool returns a small type descriptor an LLM can pass
      # straight on to get_content/browse_concept_schemes/list_concepts.
      class UniversalLookup < Base
        self.tool_name = 'universal_lookup'
        input_schema do |locale|
          {
            type: 'object',
            properties: { id: openapi_property('resolveUniversal', 'id', locale:, extra: argument_description('id', locale:)) },
            required: ['id']
          }
        end

        # Looks the id up in turn across Thing/ConceptScheme/Concept/Schedule and returns the type
        # descriptor of the first match.
        def call(arguments:, context:)
          id = arguments[:id]

          if (thing = context[:base_query].query.find_by(id:))
            { type: 'thing', id: thing.id, template_name: thing.template_name, title: thing.attribute_to_h(thing.title_property_name) }
          elsif (concept_scheme = DataCycleCore::ConceptScheme.find_by(id:))
            { type: 'concept_scheme', id: concept_scheme.id, name: concept_scheme.name }
          elsif (concept = DataCycleCore::Concept.find_by(id:))
            concept_descriptor(concept)
          elsif DataCycleCore::Schedule.exists?(id:)
            { type: 'schedule', id: }
          else
            { error: DataCycleCore::Mcp::Translations.t('errors.unknown_id', id:) }
          end
        end

        private

        # concept_scheme_id is nullable on concepts, and compact omits it rather than carrying it
        # as null, as with the other descriptors.
        def concept_descriptor(concept)
          { type: 'concept', id: concept.id, name: concept.name, concept_scheme_id: concept.concept_scheme_id }.compact
        end
      end
    end
  end
end
