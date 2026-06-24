# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ImportConceptSchemesTest < DataCycleCore::TestCases::ActiveSupportTestCase
    DummyExternalSource = Struct.new(:id, :default_options)
    DummyUtilityObject = Struct.new(:external_source)

    before(:all) do
      @subject = DataCycleCore::Generic::Common::ImportConceptSchemes
      @local_system = DataCycleCore::ExternalSystem.find_by(identifier: 'local-system')
      @remote_system = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system')
      @utility_object = DummyUtilityObject.new(DummyExternalSource.new('53a82828-d3aa-4765-99ca-7aef176de1c2', {}))
      @db_utility_object = DummyUtilityObject.new(@local_system)

      @existing_local = DataCycleCore::ClassificationTreeLabel.create!(name: 'ICSS Local Scheme', external_source_id: @local_system.id, external_key: 'icss-local-key', visibility: ['api'])
      @existing_remote = DataCycleCore::ClassificationTreeLabel.create!(name: 'ICSS Remote Scheme', external_source_id: @remote_system.id)
    end

    test 'process_content transforms raw data into concept scheme hash' do
      raw_data = { 'id' => 'cs1', 'name' => 'Scheme One' }
      result = @subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options: { import: { locales: ['de'] } })

      assert_equal('cs1', result[:external_key])
      assert_equal('Scheme One', result[:name])
      assert_equal(@utility_object.external_source.id, result[:external_source_id])
      assert_equal(DataCycleCore.default_classification_visibilities, result[:visibility])
      assert(result[:created_at].present? && result[:updated_at].present?)
      assert_not(result.key?(:external_system_identifier))
    end

    test 'process_content falls back to name as external id and applies prefix' do
      raw_data = { 'name' => 'Scheme Two' }
      options = { import: { locales: ['de'], external_id_prefix: 'PRE-' } }
      result = @subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options:)

      assert_equal('PRE-Scheme Two', result[:external_key])
    end

    test 'process_content returns nil for blank input or missing name' do
      options = { import: { locales: ['de'] } }

      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data: {}, locale: :de, options:))
      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data: { 'id' => 'x', 'name' => 'X' }, locale: :de, options: {}))
      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data: { 'id' => 'x' }, locale: :de, options:))
    end

    test 'process_content only processes allowed locales' do
      raw_data = { 'id' => 'cs1', 'name' => 'Scheme One' }
      options = { import: { locales: ['en'] } }

      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options:))
    end

    test 'process_content excludes configured concept schemes' do
      raw_data = { 'id' => 'cs1', 'name' => 'Excluded Scheme' }
      options = { import: { locales: ['de'], exclude_concept_schemes: ['Excluded Scheme'] } }

      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options:))
    end

    test 'process_content maps concept scheme names' do
      raw_data = { 'name' => 'Old Scheme Name' }
      options = { import: { locales: ['de'], concept_scheme_name_mapping: { 'Old Scheme Name' => 'New Scheme Name' } } }
      result = @subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options:)

      assert_equal('New Scheme Name', result[:name])
      assert_equal('Old Scheme Name', result[:external_key])
    end

    test 'process_content skips schemes from the current instance' do
      raw_data = { 'id' => 'cs1', 'name' => 'Scheme One', 'external_system_identifier' => 'self-system' }
      options = { import: { locales: ['de'] }, current_instance_identifiers: ['self-system'] }

      assert_nil(@subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options:))
    end

    test 'process_content uses external_key property when external_system_identifier is present' do
      raw_data = { 'id' => 'cs1', 'name' => 'Scheme One', 'external_system_identifier' => 'other-system', 'external_key' => 'remote-key' }
      result = @subject.process_content(utility_object: @utility_object, raw_data:, locale: :de, options: { import: { locales: ['de'] } })

      assert_equal('remote-key', result[:external_key])
      assert_equal('other-system', result[:external_system_identifier])
    end

    test 'default_visibility prefers configured visibility' do
      assert_equal(['api'], @subject.default_visibility({ import: { concept_scheme_default_visibility: ['api'] } }))
      assert_equal(DataCycleCore.default_classification_visibilities, @subject.default_visibility({}))
    end

    test 'extract_property digs path from options or falls back to identifier' do
      options = { import: { concept_scheme_name_path: 'nested.label' } }

      assert_equal('Deep Name', @subject.extract_property({ 'nested' => { 'label' => 'Deep Name' } }, options, 'name'))
      assert_equal('Plain Name', @subject.extract_property({ 'name' => 'Plain Name' }, {}, 'name'))
    end

    test 'external_system_identifiers_to_ids keeps new schemes and slices allowed keys' do
      now = Time.zone.now
      data_array = [{ external_key: 'n1', name: 'ICSS Brand New', external_source_id: @local_system.id, created_at: now, updated_at: now, visibility: ['api'], extra_key: 'dropped' }]
      result = @subject.external_system_identifiers_to_ids(data_array:, options: {}, utility_object: @db_utility_object)

      assert_equal([{ external_key: 'n1', name: 'ICSS Brand New', external_source_id: @local_system.id, created_at: now, updated_at: now, visibility: ['api'] }], result)
    end

    test 'external_system_identifiers_to_ids reuses external_key and visibility of existing schemes' do
      data_array = [{ external_key: 'changed-key', name: 'ICSS Local Scheme', external_source_id: @local_system.id, visibility: ['filter'] }]
      result = @subject.external_system_identifiers_to_ids(data_array:, options: {}, utility_object: @db_utility_object)

      assert_equal('icss-local-key', result.first[:external_key])
      assert_equal(['api'], result.first[:visibility])
    end

    test 'external_system_identifiers_to_ids skips duplicates from other sources by default' do
      data_array = [{ external_key: 'dup-key', name: 'ICSS Remote Scheme', external_source_id: @local_system.id }]
      result = @subject.external_system_identifiers_to_ids(data_array:, options: {}, utility_object: @db_utility_object)

      assert_empty(result)
    end

    test 'external_system_identifiers_to_ids prefixes duplicates when import_duplicates is enabled' do
      data_array = [{ external_key: 'dup-key', name: 'ICSS Remote Scheme', external_source_id: @local_system.id }]
      options = { import: { import_duplicates: true } }
      result = @subject.external_system_identifiers_to_ids(data_array:, options:, utility_object: @db_utility_object)

      assert_equal("#{@local_system.name} - ICSS Remote Scheme", result.first[:name])
    end

    test 'external_system_identifiers_to_ids raises when prefixed scheme exists from another source' do
      DataCycleCore::ClassificationTreeLabel.create!(name: 'ICSS Conflict', external_source_id: @remote_system.id)
      DataCycleCore::ClassificationTreeLabel.create!(name: "#{@local_system.name} - ICSS Conflict", external_source_id: @remote_system.id)
      data_array = [{ external_key: 'conflict-key', name: 'ICSS Conflict', external_source_id: @local_system.id }]
      options = { import: { import_duplicates: true } }

      assert_raises(RuntimeError) do
        @subject.external_system_identifiers_to_ids(data_array:, options:, utility_object: @db_utility_object)
      end
    end

    test 'external_system_identifiers_to_ids resolves external_system_identifier to external_source_id' do
      data_array = [{ external_key: 'es-key', name: 'ICSS ES Scheme', external_system_identifier: 'remote-system' }]
      result = @subject.external_system_identifiers_to_ids(data_array:, options: {}, utility_object: @db_utility_object)

      assert_equal(@remote_system.id, result.first[:external_source_id])
    end

    test 'external_system_identifiers_to_ids creates missing external systems on demand' do
      data_array = [{ external_key: 'new-es-key', name: 'ICSS New ES Scheme', external_system_identifier: 'icss-new-system' }]
      options = { import: { import_external_systems: true } }
      result = @subject.external_system_identifiers_to_ids(data_array:, options:, utility_object: @db_utility_object)
      new_system = DataCycleCore::ExternalSystem.find_by(identifier: 'icss-new-system')

      assert_not_nil(new_system)
      assert_equal(new_system.id, result.first[:external_source_id])
    end
  end
end
