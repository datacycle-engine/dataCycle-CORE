# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # [#50050] The agents are created on demand, one per degree of AI involvement and name,
  # identified by the external_key set on creation.
  class AiAgentServiceTest < DataCycleCore::TestCases::ActiveSupportTestCase
    Subject = DataCycleCore::AiAgentService
    Reference = DataCycleCore::Generic::Common::DataReferenceTransformations::AiAgentReference
    GENERATED = 'odta:AIGenerated'
    INVOLVED = 'odta:AIInvolved'
    MODIFIED = 'odta:AIModified'
    DEFAULT_NAME_DE = 'KI-Agent'
    DEFAULT_NAME_EN = 'AI agent'
    # the name part of the external_key of a nameless agent - a literal, not the displayed name
    KEY_NAME = Subject::DEFAULT_NAME

    def concept_for(degree)
      DataCycleCore::Concept.for_tree(Subject::CONCEPT_SCHEME).find_by!(external_key: degree)
    end

    def agents
      DataCycleCore::Thing.where(template_name: Subject::TEMPLATE_NAME)
    end

    # the template comes from the schema gems: a required property the service does not write makes
    # set_data_hash return false, since new_content validates all of them strictly
    def require_unwritten_property!
      thing_template = DataCycleCore::ThingTemplate.find_by!(template_name: Subject::TEMPLATE_NAME)
      thing_template.schema['properties']['unwritten'] = {
        'label' => 'Unwritten',
        'type' => 'string',
        'storage_location' => 'value',
        'validations' => { 'required' => true }
      }
      thing_template.define_singleton_method(:readonly?) { false }
      thing_template.update_column(:schema, thing_template.schema)
      DataCycleCore::ThingTemplate.reset_template_caches!
    end

    # what a concept scheme re-import that drops and re-creates the degree leaves behind: the same
    # concept, a new classification, and the old id valid nowhere
    def replace_classification_of!(degree)
      concept = concept_for(degree)
      # no external_key: the one of the degree is still taken by the classification replaced below,
      # and the service resolves the concept, never the classification
      replacement = DataCycleCore::Classification.create!(name: concept.internal_name)

      DataCycleCore::Concept.where(id: concept.id).update_all(classification_id: replacement.id)
      DataCycleCore::Classification.find(concept.classification_id).destroy

      replacement.id
    end

    def count_webhooks(action, &)
      counter = 0
      "DataCycleCore::Webhook::#{action.to_s.classify}".constantize.stub(:execute_all, ->(*) { counter += 1 }, &)
      counter
    end

    test 'creates the agent of a degree of involvement with its external_key' do
      agent = Subject.find_or_create(Reference.new(GENERATED, nil))

      assert_equal("#{KEY_NAME}-#{GENERATED}", agent.external_key)
      assert_nil(agent.external_source_id)
      assert_equal(DEFAULT_NAME_DE, agent.name)
      assert_equal([concept_for(GENERATED).classification_id], agent.get_data_hash[Subject::DEGREE_PROPERTY])
    end

    test 'the template does not compute the external_key' do
      thing_template = DataCycleCore::ThingTemplate.find_by(template_name: Subject::TEMPLATE_NAME)

      assert_nil(thing_template.schema.dig('properties', 'external_key', 'compute'))
    end

    test 'keeps the external_key when the agent is saved again' do
      agent = Subject.find_or_create(Reference.new(GENERATED, nil))

      agent.set_data_hash(
        data_hash: { Subject::DEGREE_PROPERTY => [concept_for(GENERATED).classification_id] },
        force_update: true,
        prevent_history: true
      )

      assert_equal("#{KEY_NAME}-#{GENERATED}", agent.reload.external_key)
    end

    test 'names the agent as the supplier delivers it' do
      default_agent = Subject.find_or_create(Reference.new(GENERATED, nil))
      named_agent = Subject.find_or_create(Reference.new(GENERATED, 'Opus 5'))

      assert_equal("Opus 5-#{GENERATED}", named_agent.external_key)
      assert_equal('Opus 5', named_agent.name)
      assert_not_equal(default_agent.id, named_agent.id)
    end

    # a delivered name is as raw as the supplier sends it, and it is part of the key
    test 'normalizes the delivered agent name' do
      agent = Subject.find_or_create(Reference.new(GENERATED, 'Opus 5'))
      padded = Subject.find_or_create(Reference.new(GENERATED, "  Opus 5\n"))

      assert_equal(agent.id, padded.id)
      assert_equal('Opus 5', padded.name)
      assert_equal(1, agents.count)
    end

    test 'creates one agent per degree of involvement' do
      generated = Subject.find_or_create(Reference.new(GENERATED, nil))
      modified = Subject.find_or_create(Reference.new(MODIFIED, nil))

      assert_not_equal(generated.id, modified.id)
      assert_equal(2, agents.count)
    end

    test 'resolves the same agent for a reference that already exists' do
      agent = Subject.find_or_create(Reference.new(GENERATED, nil))
      again = Subject.find_or_create(Reference.new(GENERATED, nil))

      assert_equal(agent.id, again.id)
      assert_equal(1, agents.count)
    end

    test 'resolves a degree of involvement delivered as the uri of its concept' do
      agent = Subject.find_or_create(Reference.new(concept_for(INVOLVED).uri, nil))

      assert_equal("#{KEY_NAME}-#{INVOLVED}", agent.external_key)
      assert_equal([concept_for(INVOLVED).classification_id], agent.get_data_hash[Subject::DEGREE_PROPERTY])
    end

    # a concept scheme can identify its concepts by uri alone - the key falls back to it instead
    # of collapsing every degree of such a scheme onto an empty external_key
    test 'keys an agent of a concept without an external_key by its uri' do
      # the config importer always derives an external_key, so drop it the way an import of a
      # vocabulary would leave the concept: identified by its uri only
      DataCycleCore::Concept.where(uri: MODIFIED).update_all(external_key: nil)

      agent = Subject.find_or_create(Reference.new(MODIFIED, nil))

      assert_equal("#{KEY_NAME}-#{MODIFIED}", agent.external_key)
    end

    test 'creates no agent for an unknown degree of involvement' do
      assert_nil(Subject.find_or_create(Reference.new('odta:NotADegree', nil)))
      assert_equal(0, agents.count)
    end

    test 'creates no agent without a degree of involvement' do
      assert_nil(Subject.find_or_create(Reference.new(nil, 'Opus 5')))
      assert_equal(0, agents.count)
    end

    test 'creates no agent without the agent template' do
      DataCycleCore::ThingTemplate.where(template_name: Subject::TEMPLATE_NAME).delete_all

      assert_nil(Subject.find_or_create(Reference.new(GENERATED, nil)))
      assert_equal(0, agents.count)
    end

    test 'translates the agent into every locale the degree of involvement is translated into' do
      agent = Subject.find_or_create(Reference.new(GENERATED, nil))

      assert_equal([:de, :en], agent.translated_locales.map(&:to_sym).sort)

      [:de, :en].each do |locale|
        # the description is computed from the degree of involvement, so it differs per locale
        I18n.with_locale(locale) { assert_equal(concept_for(GENERATED).name, agent.reload.description) }
      end
    end

    # the name is written per locale by the resolver, not by a default_value of the template,
    # which would be a single literal and label the English translation in German too
    test 'names the agent in every locale it is created in' do
      agent = Subject.find_or_create(Reference.new(GENERATED, nil))

      I18n.with_locale(:de) { assert_equal(DEFAULT_NAME_DE, agent.reload.name) }
      I18n.with_locale(:en) { assert_equal(DEFAULT_NAME_EN, agent.reload.name) }
    end

    # new_content marks the save as a creation, so per locale it announces one content twice
    test 'announces the agent as created once, not once per locale' do
      created = count_webhooks(:create) { Subject.find_or_create(Reference.new(GENERATED, nil)) }

      assert_equal(2, agents.sole.translated_locales.size)
      assert_equal(1, created)
    end

    # a localized name would key the same agent differently per import locale
    test 'keys the agent independently of the locale it is created in' do
      de_agent = I18n.with_locale(:de) { Subject.find_or_create(Reference.new(GENERATED, nil)) }
      en_agent = I18n.with_locale(:en) { Subject.find_or_create(Reference.new(GENERATED, nil)) }

      assert_equal("#{KEY_NAME}-#{GENERATED}", de_agent.external_key)
      assert_equal(de_agent.id, en_agent.id)
      assert_equal(1, agents.count)
    end

    # without the explicit rollback the bare row from #save! commits and is resolved from then on
    test 'leaves no agent behind when the data hash is rejected' do
      require_unwritten_property!

      assert_nil(Subject.find_or_create(Reference.new(GENERATED, nil)))
      assert_equal(0, agents.count)
      assert_nil(agents.find_by(external_key: "#{KEY_NAME}-#{GENERATED}"))
    end

    # ... and the retry must not find a half-created agent either
    test 'resolves nothing on a later call when the data hash stays rejected' do
      require_unwritten_property!

      assert_nil(Subject.find_or_create(Reference.new(GENERATED, nil)))
      assert_nil(Subject.find_or_create(Reference.new(GENERATED, nil)))
      assert_equal(0, agents.count)
    end

    # the case the requires_new of #create_agent exists for: a caller with an open transaction, as
    # the compute path has - without it the Rollback is swallowed and the bare row survives.
    # The two tests above cannot see it: the harness' own transaction is not joinable, so their
    # rollback runs in a savepoint either way.
    test 'leaves no agent behind when the data hash is rejected inside a caller transaction' do
      require_unwritten_property!

      DataCycleCore::Thing.transaction do
        assert_nil(Subject.find_or_create(Reference.new(GENERATED, nil)))
      end

      assert_equal(0, agents.count)
    end

    # a project overriding the label must not split the shared reference data
    test 'keys the agent independently of the label it is displayed with' do
      agent = Subject.find_or_create(Reference.new(GENERATED, nil))
      label = I18n.t('artificial_intelligence_agent.name', locale: :de)

      begin
        I18n.backend.store_translations(:de, { artificial_intelligence_agent: { name: 'KI Agent' } })

        renamed = Subject.find_or_create(Reference.new(GENERATED, nil))

        assert_equal(agent.id, renamed.id)
        assert_equal("#{KEY_NAME}-#{GENERATED}", renamed.external_key)
        assert_equal(1, agents.count)
      ensure
        # deep-merges, so restoring the label is enough - it would leak into later tests otherwise
        I18n.backend.store_translations(:de, { artificial_intelligence_agent: { name: label } })
      end
    end

    # a classification_id held from an earlier call writes a classification_content nothing resolves,
    # and there is no foreign key on it - the degree would just be gone
    test 'stores the current classification when the degree of involvement was re-created' do
      Subject.find_or_create(Reference.new(GENERATED, nil))
      classification_id = replace_classification_of!(GENERATED)

      agent = Subject.find_or_create(Reference.new(GENERATED, 'Opus 5'))

      # a stale id is rejected while its classification is soft-deleted, stored silently once it is
      # really gone - so pin both shapes of the failure
      assert_not_nil(agent)
      assert_equal([classification_id], agent.get_data_hash[Subject::DEGREE_PROPERTY])
    end

    test 'creates the agent of a degree of involvement that is only translated into one locale' do
      agent = Subject.find_or_create(Reference.new(MODIFIED, nil))

      assert_equal([:de], agent.translated_locales.map(&:to_sym))
      assert_equal(concept_for(MODIFIED).name, agent.description)
    end

    test 'maps every unique reference to its agent and skips unknown degrees' do
      references = [
        Reference.new(GENERATED, nil),
        Reference.new(GENERATED, nil),
        Reference.new(GENERATED, 'Opus 5'),
        Reference.new('odta:NotADegree', nil)
      ]

      mapping_table = Subject.mapping_table(references)

      assert_equal(2, mapping_table.size)
      assert_equal(2, agents.count)
      assert_equal(agents.find_by(external_key: "#{KEY_NAME}-#{GENERATED}").id, mapping_table[Reference.new(GENERATED, nil)])
      assert_equal(agents.find_by(external_key: "Opus 5-#{GENERATED}").id, mapping_table[Reference.new(GENERATED, 'Opus 5')])
      assert_not_includes(mapping_table.keys, Reference.new('odta:NotADegree', nil))
    end

    # what a supplier that names its agent per image delivers: #uniq keeps one reference per name, so
    # the degree they all share must not be resolved once per name
    test 'resolves a degree shared by differently named agents with a single lookup' do
      references = Array.new(5) { |index| Reference.new(GENERATED, "Agent #{index}") }
      Subject.mapping_table(references)

      lookups = 0
      counter = ->(_n, _s, _f, _i, payload) { lookups += 1 if payload[:sql]&.match?(/"concepts"\."(external_key|uri)"/) }

      ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
        assert_equal(5, Subject.mapping_table(references).size)
      end

      assert_equal(5, agents.count)
      assert_equal(1, lookups)
    end

    test 'resolves an ai agent reference of an import to the id of its agent' do
      raw_data = Generic::Common::DataReferenceTransformations.add_ai_agent_references({ 'ai' => { 'degree' => GENERATED } }, ['ai', 'degree'])

      resolved_data = Generic::Common::DataReferenceTransformations.resolve_references(raw_data)

      assert_equal([agents.sole.id], resolved_data['contributor'])
    end
  end
end
