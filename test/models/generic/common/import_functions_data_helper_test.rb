# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module DcImportDataHelperTransform
    def self.suffixed(identifier)
      "#{identifier}_x"
    end
  end

  module DcImportDataHelperProcessor
    def self.tag(data, _utility_object)
      data.merge('tagged' => true)
    end
  end

  module DcImportDataHelperPriorityProvider
    def self.list(**)
      ['system-a', 'system-b']
    end
  end

  DcImportDataHelperDummyUtilityObject = Struct.new(:merged_config, :external_source) do
    def step_config(_config)
      (merged_config || {}).with_indifferent_access
    end
  end

  class GenericCommonImportFunctionsDataHelperTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SUBJECT = DataCycleCore::Generic::Common::ImportFunctions

    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.create!(
        name: 'Import Data Helper Test System',
        identifier: 'import-data-helper-test-system',
        default_options: {},
        config: {
          'import_config' => {
            'functions test' => {
              'source_type' => 'ifdh_things',
              'import_strategy' => 'DataCycleCore::Generic::Common::ImportContents'
            }
          }
        }
      )
    end

    after(:all) do
      DataCycleCore::MongoHelper.drop_mongo_db('import-data-helper-test-system')
    end

    def utility_object(source_type, locales: [:de])
      DataCycleCore::Generic::ImportObject.new(
        external_source: @external_source,
        locales:,
        import: {
          source_type:,
          name: 'functions test',
          import_strategy: 'DataCycleCore::Generic::Common::ImportContents'
        }
      )
    end

    def dummy_source(identifier: 'dummy-system', name: 'Dummy System')
      Struct.new(:identifier, :name).new(identifier, name)
    end

    # ---- pure helpers ----

    test 'default_classification resolves a classification id from tree label and name' do
      ids = SUBJECT.send(:default_classification, value: 'Tag 3', tree_label: 'Tags')

      assert_equal 1, ids.size
      assert_includes get_classification_ids('Tags', 'Tag 3'), ids.first
    end

    test 'load_default_values maps configured default values to classification ids' do
      assert_nil SUBJECT.load_default_values(nil)
      assert_nil SUBJECT.load_default_values({})

      result = SUBJECT.load_default_values({ 'my_tags' => { value: 'Tag 3', tree_label: 'Tags' } })

      assert_equal get_classification_ids('Tags', 'Tag 3').first, result['my_tags'].first
    end

    test 'transform_external_system_data! applies identifier mapping and transformation' do
      merged = {
        'import_external_system_data' => true,
        'external_system_identifier_mapping' => { 'old' => 'mapped' },
        'external_system_identifier_transformation' => {
          'module' => 'DataCycleCore::DcImportDataHelperTransform',
          'method' => 'suffixed'
        }
      }
      utility = DcImportDataHelperDummyUtilityObject.new(merged, dummy_source)
      data_hash = { 'external_system_data' => [{ 'identifier' => 'old' }, { 'identifier' => 'keep' }] }

      SUBJECT.send(:transform_external_system_data!, {}, data_hash, utility)

      assert_equal ['mapped_x', 'keep_x'], data_hash['external_system_data'].pluck('identifier')
    end

    test 'transform_external_system_data! removes foreign system data when import is disabled' do
      utility = DcImportDataHelperDummyUtilityObject.new({}, dummy_source(identifier: 'keep-id', name: 'Keep'))
      data_hash = { 'external_system_data' => [{ 'identifier' => 'keep-id' }, { 'identifier' => 'drop-id' }] }

      SUBJECT.send(:transform_external_system_data!, {}, data_hash, utility)

      assert_equal ['keep-id'], data_hash['external_system_data'].pluck('identifier')
    end

    test 'pre_process_data applies whitelist, blacklist and processors' do
      config = {
        before: {
          whitelist: [['name'], ['external_key']],
          blacklist: [['drop']],
          processors: [{ module: 'DataCycleCore::DcImportDataHelperProcessor', method: ['tag', 'missing_method'] }]
        }
      }
      raw_data = { 'name' => 'N', 'external_key' => 'K', 'drop' => 'x', 'extra' => 'y' }

      result = SUBJECT.send(:pre_process_data, raw_data:, config:, utility_object: utility_object('ifdh_pre'))

      assert result['tagged']
      assert_nil result['extra']
      assert_nil result['drop']
      assert_equal 'N', result['name']
    end

    test 'post_process_data applies whitelist, blacklist and processors' do
      config = {
        after: {
          whitelist: [['name'], ['external_key']],
          blacklist: [['drop']],
          processors: [{ module: 'DataCycleCore::DcImportDataHelperProcessor', method: ['tag', 'missing_method'] }]
        }
      }
      data = { 'name' => 'N', 'external_key' => 'K', 'drop' => 'x', 'extra' => 'y' }

      result = SUBJECT.send(:post_process_data, data:, config:, utility_object: utility_object('ifdh_post'))

      assert result['tagged']
      assert_nil result['extra']
      assert_equal 'N', result['name']
    end

    test 'primary_system_priority_list resolves a module/method hash configuration' do
      config = {
        primary_system_priority: {
          module: 'DataCycleCore::DcImportDataHelperPriorityProvider',
          method: 'list'
        }
      }

      assert_equal ['system-a', 'system-b'], SUBJECT.send(:primary_system_priority_list, config)
    end

    test 'instrument_import_failure publishes the failure notification' do
      captured = []
      utility = DcImportDataHelperDummyUtilityObject.new({}, dummy_source)
      template = Struct.new(:template_name).new('Artikel')

      ActiveSupport::Notifications.stub(:instrument, ->(name, payload) { captured << [name, payload] }) do
        SUBJECT.instrument_import_failure(
          exception: StandardError.new('boom'),
          utility_object: utility,
          data: { 'external_key' => 'ek-1' },
          raw_data: { 'id' => 'rid-1' },
          template:
        )
      end

      assert_equal 'object_import_failed.datacycle', captured.first.first
      assert_equal 'ek-1', captured.first.last[:item_id]
    end

    # ---- content paths ----

    test 'add_external_system_data! upserts external system syncs' do
      content = create_content('Artikel', { name: 'ESD Artikel' })
      object = utility_object('ifdh_esd')
      data = {
        'external_key' => 'esd-1',
        'external_system_data' => [{ 'identifier' => 'ifdh-sync-target', 'external_key' => 'tgt-1', 'sync_type' => 'duplicate' }]
      }

      result = SUBJECT.add_external_system_data!(content:, data:, step_config: {}, utility_object: object, update: true)

      assert result
      assert DataCycleCore::ExternalSystemSync.exists?(syncable_id: content.id, external_key: 'tgt-1')
    end

    test 'process_syncs adds external system data to an existing thing' do
      content = create_content('Artikel', { name: 'Sync Artikel' })
      object = utility_object('ifdh_syncs')
      raw_data = {
        'id' => content.id,
        'external_key' => content.id,
        'external_system_data' => [{ 'identifier' => 'ifdh-other-system', 'external_key' => 'other-1' }]
      }

      result = SUBJECT.process_syncs(
        utility_object: object,
        raw_data:,
        transformation: ->(data) { data },
        default: { template: 'Artikel' },
        config: { 'import_external_system_data' => true }
      )

      assert_equal content.id, result.id
      assert DataCycleCore::ExternalSystemSync.exists?(syncable_id: content.id, external_key: 'other-1')
    end

    test 'self_primary? returns true for local content claimed as primary by the current instance' do
      content = create_content('Artikel', { name: 'SP Local' })
      object = utility_object('ifdh_sp1')
      data = { 'external_key' => 'sp-1', 'external_system_data' => [{ 'identifier' => 'this-dc-instance', 'primary' => true }] }
      step_config = { 'current_instance_identifiers' => ['this-dc-instance'] }.with_indifferent_access

      assert SUBJECT.send(:self_primary?, content:, utility_object: object, data:, step_config:)
    end

    test 'self_primary? restores content owned by the current system back to local' do
      content = create_content('Artikel', { name: 'SP Restore' })
      object = utility_object('ifdh_sp2')
      content.update_columns(external_source_id: object.external_source.id, external_key: 'mine-1')
      data = { 'external_key' => 'sp-2', 'external_system_data' => [{ 'identifier' => 'this-dc-instance', 'primary' => true }] }
      step_config = { 'current_instance_identifiers' => ['this-dc-instance'] }.with_indifferent_access

      result = SUBJECT.send(:self_primary?, content: content.reload, utility_object: object, data:, step_config:)

      assert result
      assert_nil content.reload.external_source_id
    end

    test 'update_allowed? returns false when a foreign system may not take over as primary' do
      foreign = DataCycleCore::ExternalSystem.create!(name: 'IFDH Foreign', identifier: 'ifdh-foreign')
      content = create_content('Artikel', { name: 'UA Foreign' })
      content.update_columns(external_source_id: foreign.id, external_key: 'f-1')
      object = utility_object('ifdh_ua1')
      data = { 'external_key' => 'ua-1', 'external_system_data' => [] }

      assert_not SUBJECT.send(
        :update_allowed?,
        content: content.reload,
        utility_object: object,
        data:,
        step_config: {}.with_indifferent_access,
        step_label: 'step'
      )
    end

    test 'update_allowed? returns false when the primary key may not change' do
      content = create_content('Artikel', { name: 'UA Key' })
      object = utility_object('ifdh_ua2')
      content.update_columns(external_source_id: object.external_source.id, external_key: 'orig-key')
      data = { 'external_key' => 'new-key', 'external_system_data' => [] }

      assert_not SUBJECT.send(
        :update_allowed?,
        content: content.reload,
        utility_object: object,
        data:,
        step_config: {}.with_indifferent_access,
        step_label: 'step'
      )
    end

    test 'process_step creates content and touches the external hash on identical re-import' do
      object = utility_object('ifdh_step')
      args = {
        utility_object: object,
        raw_data: { 'external_key' => 'step-1', 'name' => 'Step Artikel' },
        transformation: ->(data) { data },
        default: { template: 'Artikel' },
        config: {}
      }

      content = SUBJECT.process_step(**args)

      assert_predicate content, :persisted?
      assert_equal 'step-1', content.external_key

      again = SUBJECT.process_step(**args)

      assert_equal content.id, again.id
    end

    test 'create_or_update_content reloads existing content on a template mismatch' do
      object = utility_object('ifdh_mismatch')
      existing = SUBJECT.process_step(
        utility_object: object,
        raw_data: { 'external_key' => 'mm-1', 'name' => 'MM Artikel' },
        transformation: ->(data) { data },
        default: { template: 'Artikel' },
        config: {}
      )
      event_template = SUBJECT.send(:load_template, 'Event')

      result = SUBJECT.create_or_update_content(
        utility_object: object,
        template: event_template,
        data: { 'external_key' => 'mm-1', 'name' => 'MM Event' },
        config: {}
      )

      assert_equal existing.id, result.id
    end
  end
end
