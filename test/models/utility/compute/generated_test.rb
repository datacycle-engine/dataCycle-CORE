# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Utility
    module Compute
      # A producer that answers the ai_agents_for hook, resolvable the way Compute::Base resolves a
      # :compute: :module: - ModuleService looks under Utility::Compute first.
      module GeneratedTestProducer
        class << self
          attr_accessor :calls

          def ai_agents_for(_content, key, locales)
            (self.calls ||= []) << [key, locales]

            locales.map { |locale| GeneratedTest.reference('odta:AIGenerated', "producer-#{locale}") }
          end
        end
      end

      # A producer that names its agent but leaves the degree to core.
      module GeneratedTestProducerWithoutDegree
        class << self
          attr_accessor :calls

          def ai_agents_for(_content, key, locales)
            (self.calls ||= []) << [key, locales]

            locales.map { |locale| GeneratedTest.reference(nil, "producer-#{locale}") }
          end
        end
      end

      # A producer whose agent changes between runs, the way a project that swaps the annotation
      # service its backend feature is configured against changes it.
      module GeneratedTestSwappedProducer
        class << self
          attr_accessor :agent_name

          def ai_agents_for(_content, _key, locales)
            locales.map { GeneratedTest.reference(nil, agent_name) }
          end
        end
      end

      class GeneratedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        DEFAULT_DEGREE = DataCycleCore::Utility::Compute::Generated::DEFAULT_DEGREE

        def self.reference(degree, name)
          DataCycleCore::Generic::Common::DataReferenceTransformations::AiAgentReference.new(degree, name)
        end

        # Stands in for a Thing: the values of the base and companion attributes per locale, and the
        # property definitions the transformer would have produced.
        class ContentDouble
          def initialize(values:, definitions:)
            @values = values
            @definitions = definitions
          end

          def available_locales
            @values.keys
          end

          def generated_property_names
            @definitions.select { |_, definition| definition.dig('features', 'generated', 'generated_for').present? }.keys
          end

          def properties_for(key)
            @definitions[key.to_s]
          end

          def generated_base_property_name(key)
            properties_for(key)&.dig('features', 'generated', 'generated_for')
          end

          def generated_blocking_property_names(key)
            Array.wrap(properties_for(key)&.dig('features', 'generated', 'blocked_by').presence || generated_base_property_name(key))
          end

          def method_missing(name, *args)
            key = name.to_s
            return @values.dig(I18n.locale.to_s, key) if attribute?(key)

            super
          end

          def respond_to_missing?(name, include_private = false)
            attribute?(name.to_s) || super
          end

          private

          def attribute?(key)
            @values.each_value.any? { |values| values.key?(key) }
          end
        end

        def subject
          DataCycleCore::Utility::Compute::Generated
        end

        def companion_definitions(compute_module = 'Common', blocked_by = ['description'])
          {
            'description' => {},
            'description_generated' => {
              'features' => { 'generated' => { 'generated_for' => 'description', 'blocked_by' => blocked_by } },
              'compute' => { 'module' => compute_module, 'method' => 'annotation_text' }
            }
          }.with_indifferent_access
        end

        def content(values, compute_module = 'Common')
          ContentDouble.new(values:, definitions: companion_definitions(compute_module))
        end

        # What the transformer marks a companion with where the editorial attribute carries an
        # overlay: the override an editor writes blocks it just as the base does.
        def overlaid_content(values)
          ContentDouble.new(values:, definitions: companion_definitions('Common', ['description', 'description_override']))
        end

        # Records what the module asked AiAgentService for and hands back an agent whose id names
        # the reference, so the assertions read as the marking a content would carry.
        def ai_agents(content, agent: :found)
          @references = []
          ids = nil

          agents_for = lambda { |references|
            @references = references
            next {} if agent == :missing

            references.index_with { |reference| "agent:#{reference.name || 'default'}:#{reference.degree}" }
          }

          DataCycleCore::AiAgentService.stub(:mapping_table, agents_for) { ids = subject.ai_agents(content:) }

          ids
        end

        test 'no marking without a generated companion' do
          plain = ContentDouble.new(values: { 'de' => { 'description' => 'Ein Feld voller Lavendel' } }, definitions: { 'description' => {} }.with_indifferent_access)

          assert_empty(ai_agents(plain))
        end

        test 'marks a generated value the editorial attribute leaves empty' do
          values = { 'de' => { 'description' => nil, 'description_generated' => 'Ein Feld voller Lavendel' } }

          assert_equal(["agent:default:#{DEFAULT_DEGREE}"], ai_agents(content(values)))
          assert_equal([DEFAULT_DEGREE], @references.map(&:degree))
          assert_nil(@references.first.name)
        end

        test 'no marking while the editorial attribute has a value' do
          values = { 'de' => { 'description' => 'Redaktionell', 'description_generated' => 'Generiert' } }

          assert_empty(ai_agents(content(values)))
          assert_empty(@references)
        end

        # The injected :condition: is evaluated with Compute::Base#not_exists?, i.e. blank?, which
        # false satisfies - while DataHashService counts false as a value. Reading the base
        # attribute through the other predicate would generate a value and mark nothing for it.
        test 'a base attribute holding false counts as empty, the way the injected condition does' do
          values = { 'de' => { 'description' => false, 'description_generated' => 'Generiert' } }

          assert_equal(["agent:default:#{DEFAULT_DEGREE}"], ai_agents(content(values)))
        end

        test 'no marking for a companion that is empty itself' do
          values = { 'de' => { 'description' => nil, 'description_generated' => nil } }

          assert_empty(ai_agents(content(values)))
        end

        # The marking hangs on the content, not on the single translation: one effective locale is
        # enough, and the agent is asked for once no matter how many locales carry a value.
        test 'marks once when several locales carry a generated value' do
          values = {
            'de' => { 'description' => 'Redaktionell', 'description_generated' => 'Generiert' },
            'en' => { 'description' => nil, 'description_generated' => 'Generated' }
          }

          assert_equal(["agent:default:#{DEFAULT_DEGREE}"], ai_agents(content(values)))
          assert_equal(1, @references.size)
        end

        test 'the producer module decides the agents and is given the effective locales' do
          GeneratedTestProducer.calls = []
          values = {
            'de' => { 'description' => nil, 'description_generated' => 'Generiert' },
            'en' => { 'description' => 'Editorial', 'description_generated' => 'Generated' }
          }

          ids = ai_agents(content(values, 'GeneratedTestProducer'))

          assert_equal([['description_generated', ['de']]], GeneratedTestProducer.calls)
          assert_equal(['agent:producer-de:odta:AIGenerated'], ids)
        end

        # AiAgentService drops a reference whose degree names no concept, so a producer that only
        # wants to name its agent must not have to repeat the degree
        test 'a producer that names only the agent gets the default degree' do
          GeneratedTestProducerWithoutDegree.calls = []
          values = { 'de' => { 'description' => nil, 'description_generated' => 'Generiert' } }

          ids = ai_agents(content(values, 'GeneratedTestProducerWithoutDegree'))

          assert_equal([DEFAULT_DEGREE], @references.map(&:degree))
          assert_equal(["agent:producer-de:#{DEFAULT_DEGREE}"], ids)
        end

        # Swapping the annotation service a project is configured against re-annotates whatever it
        # recomputes, and the marking has to follow rather than accumulate: this answers with the
        # full set the current producer names, which is what :fallback: false then stores.
        test 'a producer that changes its agent replaces the marking instead of adding to it' do
          values = { 'de' => { 'description' => nil, 'description_generated' => 'Generiert' } }
          image = content(values, 'GeneratedTestSwappedProducer')

          GeneratedTestSwappedProducer.agent_name = 'PixieLens'

          assert_equal(["agent:PixieLens:#{DEFAULT_DEGREE}"], ai_agents(image))

          GeneratedTestSwappedProducer.agent_name = 'OtherLens'

          assert_equal(["agent:OtherLens:#{DEFAULT_DEGREE}"], ai_agents(image))
        end

        # An override leaves the base attribute empty, so weighing the base alone would keep the
        # marking on a content whose API delivers the editor's text.
        test 'an override ends the marking although the base attribute stays empty' do
          values = {
            'de' => { 'description' => nil, 'description_override' => 'Redaktionelles Overlay', 'description_generated' => 'Generiert' }
          }

          assert_empty(ai_agents(overlaid_content(values)))
        end

        # The discriminating counterpart: a base attribute that is filled has to end the marking
        # whether or not an override sits next to it, so this fails on a template that weighs the
        # override alone.
        test 'a filled base attribute ends the marking although the override is empty' do
          values = {
            'de' => { 'description' => 'Redaktionell', 'description_override' => nil, 'description_generated' => 'Generiert' }
          }

          assert_empty(ai_agents(overlaid_content(values)))
        end

        test 'the marking stands while neither the base attribute nor the override carries anything' do
          values = {
            'de' => { 'description' => nil, 'description_override' => nil, 'description_generated' => 'Generiert' }
          }

          assert_equal(["agent:default:#{DEFAULT_DEGREE}"], ai_agents(overlaid_content(values)))
        end

        # The window between deploying this and running the config sync: every thing_templates row
        # still carries only the pre-#51643 marker, and the companion has to keep working.
        test 'a marker without blocked_by falls back to the base attribute' do
          definitions = {
            'description' => {},
            'description_generated' => {
              'features' => { 'generated' => { 'generated_for' => 'description' } },
              'compute' => { 'module' => 'Common', 'method' => 'annotation_text' }
            }
          }.with_indifferent_access
          values = { 'de' => { 'description' => nil, 'description_generated' => 'Generiert' } }

          assert_equal(["agent:default:#{DEFAULT_DEGREE}"], ai_agents(ContentDouble.new(values:, definitions:)))
        end

        test 'an unresolvable agent leaves the marking empty instead of failing' do
          values = { 'de' => { 'description' => nil, 'description_generated' => 'Generiert' } }

          assert_empty(ai_agents(content(values), agent: :missing))
        end
      end
    end
  end
end
