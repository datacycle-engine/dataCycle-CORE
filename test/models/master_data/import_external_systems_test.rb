# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::MasterData::ImportExternalSystems do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::MasterData::ImportExternalSystems
  end

  describe 'loaded external_sources_config' do
    let(:import_path) do
      Rails.root.join('..', 'fixtures', 'external_systems')
    end

    let(:external_source) do
      import_path.join('remote_system.yml')
    end

    let(:external_source_config) do
      YAML.safe_load(File.open(external_source), permitted_classes: [Symbol]).to_h
    end

    let(:external_source_download_contract) do
      subject::ExternalSystemDownloadContract.new
    end

    let(:external_source_import_contract) do
      subject::ExternalSystemImportContract.new
    end

    it 'has a config path defined' do
      assert(DataCycleCore.external_systems_path.is_a?(Array))
    end

    it 'successfully validates the test config' do
      assert(subject.validate(external_source_config).blank?)
    end

    it 'fails if no name is given' do
      assert(subject.validate(external_source_config.except('name')).present?)
    end

    it 'produces an appropriate error message if no name is given' do
      assert(subject.validate(external_source_config.except('name')), { name: ['is missing'] })
    end

    it 'fails if credentials are not an Array or Hash' do
      config = external_source_config
      config['credentials'] = 'test'
      assert(subject.validate(config).present?)
    end

    it 'produces an appropriate error message if no credentials are given' do
      assert(subject.validate(external_source_config.except('credentials')), { credentials: ['is missing'] })
    end

    it 'fails if download_config is not a Hash' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('download_config')
      test_hash['config']['download_config'] = 'test'
      assert(subject.validate(test_hash).present?)
    end

    it 'produces an appropriate error message if no download_config is given' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('download_config')
      assert(subject.validate(test_hash), { config: { download_config: ['is missing'] } })
    end

    it 'fails if import_config is not a Hash' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('import_config')
      test_hash['config']['import_config'] = 'test'
      assert(subject.validate(test_hash).present?)
    end

    it 'produces an appropriate error message if no import_config is given' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('import_config')
      assert(subject.validate(test_hash), { config: { import_config: ['is missing'] } })
    end

    it 'successfully validates a valid validate_download_item' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_download_contract.call(test_hash).errors, {})
    end

    it 'produces an appropriate error if sorting is negative' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:sorting] = -1
      assert(external_source_download_contract.call(test_hash).errors, { sorting: ['must be greater than 0'] })
    end

    it 'fails if download_item has no source_type specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_download_contract.call(test_hash.except(:source_type)).present?)
    end

    it 'produces an appropriate error if no source_type is specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_download_contract.call(test_hash.except(:source_type)).errors, { source_type: ['is missing'] })
    end

    it 'fails if download_item has no endpoint specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_download_contract.call(test_hash.except(:source_type)).present?)
    end

    it 'produces an appropriate error if no endpoint is specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_download_contract.call(test_hash.except(:endpoint)).errors, { endpoint: ['is missing'] })
    end

    it 'produces an appropriate error if endpoint is not a valid class_name' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:endpoint] = 'DataCycleCore::XXX'
      assert(external_source_download_contract.call(test_hash).errors, { endpoint: ['the string given does not specify a valid ruby class.'] })
    end

    it 'fails if download_item has no download_strategy specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_download_contract.call(test_hash.except(:download_strategy)).present?)
    end

    it 'produces an appropriate error if no download_strategy is specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_download_contract.call(test_hash.except(:download_strategy)), { download_strategy: ['is missing'] })
    end

    it 'produces an appropriate error if download_strategy is not a module' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:download_strategy] = 'DataCycleCore::XXX'
      assert(external_source_download_contract.call(test_hash).errors, { download_strategy: ['the string given does not specify a valid ruby module.'] })
    end

    it 'produces an appropriate error if logging_strategy is not a module' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:logging_strategy] = 'DataCycleCore::XXX'
      assert(external_source_download_contract.call(test_hash).errors, { logging_strategy: ['the string given can not be evaluated.'] })
    end

    it 'produces an appropriate error if sorting is negative for an import_item' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:sorting] = -1
      assert(external_source_import_contract.call(test_hash).errors, { sorting: ['must be greater than 0'] })
    end

    it 'fails if import_item has no source_type specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_import_contract.call(test_hash.except(:source_type)).present?)
    end

    it 'produces an appropriate error if no source_type is specified for an import_item' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_import_contract.call(test_hash.except(:source_type)), { source_type: ['is missing'] })
    end

    it 'fails if import_item has no import_strategy specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_import_contract.call(test_hash.except(:import_strategy)).present?)
    end

    it 'produces an appropriate error if no import_strategy is specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_import_contract.call(test_hash.except(:import_strategy)), { import_strategy: ['is missing'] })
    end

    it 'produces an appropriate error if import_strategy is not a valid class_name' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:import_strategy] = 'DataCycleCore::XXX'
      assert(external_source_import_contract.call(test_hash).errors, { import_strategy: ['the string given does not specify a valid ruby module.'] })
    end

    it 'fails if import_item has no data_template specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_import_contract.call(test_hash.except(:data_template)).present?)
    end

    it 'check that data_template is optional' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      assert(external_source_import_contract.call(test_hash.except(:data_template)).errors, {})
    end
  end
end
