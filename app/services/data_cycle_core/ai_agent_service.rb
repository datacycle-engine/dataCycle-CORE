# frozen_string_literal: true

module DataCycleCore
  # [#50050] Resolves a degree of AI involvement to an ArtificialIntelligenceAgent content
  # (transparency obligations of Art. 50 EU AI Act, in force from 02.08.2026).
  #
  # The contents are created on demand and are reference data without an external_source_id, so
  # every producer of AI content links to the same agent per degree of involvement - and per name,
  # where one is given. Importers reach this through DataReferenceTransformations, everything else
  # calls find_or_create directly.
  class AiAgentService
    CONCEPT_SCHEME = 'ODTA - AI-DegreeOfInvolvement'
    TEMPLATE_NAME = 'ArtificialIntelligenceAgent'
    DEGREE_PROPERTY = 'odta_ai_degree_of_involvement'
    KEY_SEPARATOR = '-'
    # name part of the key of an unnamed agent, and the display fallback. A literal on purpose: the
    # key must not move when a project overrides 'artificial_intelligence_agent.name'.
    DEFAULT_NAME = 'AI agent'

    class << self
      # @param references [Array<#degree, #name>] e.g. the AiAgentReferences of an import
      # @return [Hash{Object => String}] reference to the id of its agent content
      def mapping_table(references)
        return {} if references.blank? || !template_exists?

        unique_references = references.uniq
        # One lookup per distinct degree instead of per reference: #uniq keeps a reference per name,
        # so a supplier naming its agent per image would resolve the same degree once per name.
        concepts = unique_references.map(&:degree).uniq.index_with { |degree| concept_for(degree) }

        unique_references.index_with { |reference| agent_for(reference, concepts[reference.degree])&.id }.compact
      end

      # @param reference [#degree, #name] the degree of involvement as the external_key or uri of
      #   a concept of CONCEPT_SCHEME, with an optional agent name
      # @return [DataCycleCore::Thing, nil] nil if the template or the degree is unknown, or the
      #   agent could not be created - none of which may block the import of the content itself
      def find_or_create(reference)
        return unless template_exists?

        agent_for(reference)
      end

      private

      # The template ships with the schema gems - a project without it must not have its imports
      # fail. Cached by ThingTemplate, which invalidates on any template write.
      def template_exists?
        DataCycleCore::ThingTemplate.cached_by_template_name(TEMPLATE_NAME).present?
      end

      # expects the caller to have checked #template_exists?
      #
      # @param concept [DataCycleCore::Concept, nil] the resolved degree, for a caller that shares
      #   one lookup across several references
      def agent_for(reference, concept = concept_for(reference.degree))
        return if concept.nil?

        # a delivered name arrives as raw as the supplier sends it - the strip_all of an importer
        # runs on the data hash and never reaches a reference, and the name is part of the key
        name = reference.name.to_s.strip.presence
        external_key = external_key_for(concept, name)

        existing_agent(external_key) || create_agent(concept, name, external_key)
      end

      # Suppliers deliver the degree as the concept's external_key or uri (odta:AIGenerated, ...).
      # Not cached beyond the single call of #mapping_table: a classification_id kept past its
      # classification stores a classification_content nothing resolves, and Concept is readonly, so
      # there is no write to invalidate a cache on.
      def concept_for(degree)
        return if degree.blank?

        concepts = DataCycleCore::Concept.for_tree(CONCEPT_SCHEME)

        concepts.find_by(external_key: degree.to_s) || concepts.find_by(uri: degree.to_s)
      end

      def existing_agent(external_key)
        DataCycleCore::Thing.find_by(template_name: TEMPLATE_NAME, external_source_id: nil, external_key:)
      end

      # Name plus degree ('AI agent-odta:AIGenerated'), so there is one agent per degree and name.
      # The name part is the DEFAULT_NAME literal, never the localized one (see #data_hash) - the key
      # identifies shared reference data and must not depend on locale or label.
      #
      # A concept scheme may identify its concepts by uri alone, so fall back to it; #concept_for
      # matched one of the two, so they are never both blank.
      def external_key_for(concept, name)
        [name.presence || DEFAULT_NAME, concept.external_key.presence || concept.uri].compact_blank.join(KEY_SEPARATOR)
      end

      # The row has to exist before the data hash can be written, so both steps share a transaction.
      # set_data_hash signals a validation error by returning false, so the rollback must be explicit
      # - otherwise the bare row from #save! commits and #existing_agent resolves to it for good.
      # requires_new, or a caller's open transaction would swallow the Rollback (see #lock!).
      #
      # new_content pulls in the default_values missing from the data hash (without it: no data_pool),
      # but also counts the save as a creation - so first locale only, or the create webhook fires
      # once per locale. Both mirror Content::DataHash#set_data_hash_with_translations.
      def create_agent(concept, name, external_key)
        DataCycleCore::Thing.transaction(joinable: false, requires_new: true) do
          lock!(external_key)

          existing_agent(external_key) || begin
            agent = DataCycleCore::Thing.new(template_name: TEMPLATE_NAME, external_key:)
            agent.save!(touch: false)

            locales_for(concept).each_with_index do |locale, index|
              valid = I18n.with_locale(locale) do
                agent.set_data_hash(data_hash: data_hash(concept, name), prevent_history: true, new_content: index.zero?)
              end

              raise ActiveRecord::Rollback unless valid
            end

            agent.reload
          end
        end
      end

      # Serializes concurrent producers: external_source_id is nil for every agent, so the unique
      # index on (external_source_id, external_key) misses the duplicate (NULLs are distinct), and a
      # row that does not exist yet cannot be locked. The re-check inside covers the gap.
      #
      # xact, so a caller's open transaction (the compute path has one) holds the lock until its own
      # commit. Deliberate: the row is invisible to other sessions until then, so an earlier release
      # would let the next producer through the re-check.
      def lock!(external_key)
        DataCycleCore::Thing.connection.execute(
          DataCycleCore::Thing.sanitize_sql_array(['SELECT pg_advisory_xact_lock(hashtext(?), hashtext(?))', TEMPLATE_NAME, external_key.to_s])
        )
      end

      # Set per locale rather than as the template's default_value, which is a single literal and
      # would label every translation in German.
      def data_hash(concept, name)
        {
          DEGREE_PROPERTY => [concept.classification_id],
          'name' => name.presence || I18n.t('artificial_intelligence_agent.name', default: DEFAULT_NAME)
        }
      end

      # the description is computed from the concept, so a locale the concept lacks would only add
      # an empty translation
      def locales_for(concept)
        locales = I18n.available_locales.select { |locale| I18n.with_locale(locale) { concept.name.present? } }

        locales.presence || [I18n.default_locale]
      end
    end
  end
end
