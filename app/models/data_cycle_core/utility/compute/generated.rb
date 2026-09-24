# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Compute
      # [#51643] The marking of the _generated companion attributes of a content: the
      # ArtificialIntelligenceAgent contents of #50050 that produced whatever generated value is
      # currently effective. Injected as 'contributor_generated' by
      # MasterData::Templates::Extensions::Generated, which is also where the naming convention and
      # the per-locale condition are documented.
      module Generated
        # "Eine KI war am Entstehungsprozess dieses Inhalts beteiligt" - the statement that holds for
        # a generated ALT label. odta:AIGenerated would claim the image itself is AI generated, so a
        # producer that really generates the content says so through the hook instead.
        DEFAULT_DEGREE = 'odta:AIInvolved'

        class << self
          # A generated value is effective while the editorial attribute next to it is empty, which
          # is a per-locale question - so the locales are walked here rather than read from
          # computed_parameters: 'contributor_generated' is a linked property, computed once for the
          # whole content, and its parameters exist to make the dependency tracker recompute it when
          # one of the attributes changes, not to supply the values.
          #
          # @param content [DataCycleCore::Thing]
          # @return [Array<String>] ids of the AI agents to link, empty when nothing is effective
          #   any more - which is what clears the marking, given :compute: :fallback: false
          def ai_agents(content:, **_args)
            return [] if content.blank?

            references = agent_references(content).uniq
            return [] if references.blank?

            # #mapping_table over #find_or_create per reference: it resolves each distinct degree
            # once, and two producers of one content normally differ only in their name
            DataCycleCore::AiAgentService.mapping_table(references).values.uniq
          end

          private

          def agent_references(content)
            Array.wrap(content.try(:generated_property_names)).flat_map do |key|
              blocking_keys = Array.wrap(content.try(:generated_blocking_property_names, key))
              next [] if blocking_keys.blank?

              locales = effective_locales(content, key, blocking_keys)
              next [] if locales.blank?

              references_for(content, key, locales)
            end
          end

          # @param blocking_keys [Array<String>] the editorial attributes that have to be empty, the
          #   same ones the injected :condition: names - see Content#generated_blocking_property_names
          def effective_locales(content, key, blocking_keys)
            Array.wrap(content.try(:available_locales)).map(&:to_s).select do |locale|
              I18n.with_locale(locale) do
                blocking_keys.all? { |blocking_key| unset?(content.try(blocking_key)) } &&
                  DataCycleCore::DataHashService.present?(content.try(key))
              end
            end
          end

          # Empty the way the injected :condition: means it, which is Compute::Base#not_exists? -
          # the method #condition_satisfied? dispatches. DataHashService.blank? is not the same
          # predicate: it counts an attribute holding false as a value, so such a content would
          # generate a companion value (its condition satisfied) and carry no agent for it.
          #
          # @param value [Object, nil] a blocking attribute in the locale being weighed
          # @return [Boolean]
          def unset?(value)
            DataCycleCore::Utility::Compute::Base.not_exists?(value, nil)
          end

          # The producer is the compute module of the companion attribute itself, so nothing has to
          # be registered anywhere. It knows which locale it filled from where - the
          # imageDescriptionPixie generated the German ALT label and left every other locale to
          # whoever fills it - and answers with one reference per agent through #ai_agents_for.
          #
          # Without the hook the content gets the collective agent AiAgentService names by default
          # ("KI-Agent"), the same one the importers link.
          #
          # @return [Array<DataCycleCore::Generic::Common::DataReferenceTransformations::AiAgentReference>]
          def references_for(content, key, locales)
            producer = producer_module(content, key)

            return [reference(nil)] unless producer.respond_to?(:ai_agents_for)

            # A reference AiAgentService cannot resolve a degree for is dropped without a word, so a
            # producer that only names its agent gets the default filled in rather than losing the
            # marking it just asked for.
            Array.wrap(producer.ai_agents_for(content, key, locales)).compact.map do |produced|
              produced.degree.presence ? produced : reference(produced.name)
            end
          end

          def reference(name)
            DataCycleCore::Generic::Common::DataReferenceTransformations::AiAgentReference.new(DEFAULT_DEGREE, name)
          end

          def producer_module(content, key)
            module_name = content.properties_for(key)&.dig('compute', 'module')
            return if module_name.blank?

            DataCycleCore::ModuleService.safe_load_module(module_name.classify, 'Utility::Compute')
          end
        end
      end
    end
  end
end
