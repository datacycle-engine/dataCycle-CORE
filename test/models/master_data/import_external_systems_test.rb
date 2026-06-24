# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'
require 'tmpdir'

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
      subject::ExternalSystemStepContract.new
    end

    let(:external_source_import_contract) do
      subject::ExternalSystemStepContract.new
    end

    it 'has a config path defined' do
      assert_kind_of(Array, DataCycleCore.external_systems_path)
    end

    it 'successfully validates the test config' do
      assert_predicate(subject.validate(external_source_config), :blank?)
    end

    it 'fails if no name is given' do
      assert_predicate(subject.validate(external_source_config.except('name')), :present?)
    end

    it 'produces an appropriate error message if no name is given' do
      assert_equal(['.name => is missing'], subject.validate(external_source_config.except('name')))
    end

    it 'fails if credentials are not an Array or Hash' do
      config = external_source_config
      config['credentials'] = 'test'

      assert_predicate(subject.validate(config), :present?)
    end

    it 'produces an appropriate error message if no credentials are given' do
      assert_empty(subject.validate(external_source_config.except('credentials')))
    end

    it 'fails if download_config is not a Hash' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('download_config')
      test_hash['config']['download_config'] = 'test'

      assert_predicate(subject.validate(test_hash), :present?)
    end

    it 'produces an appropriate error message if no download_config is given' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('download_config')

      assert_empty(subject.validate(test_hash))
    end

    it 'fails if import_config is not a Hash' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('import_config')
      test_hash['config']['import_config'] = 'test'

      assert_predicate(subject.validate(test_hash), :present?)
    end

    it 'produces an appropriate error message if no import_config is given' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('import_config')

      assert_empty(subject.validate(test_hash))
    end

    it 'successfully validates a valid validate_download_item' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup

      assert_empty(external_source_download_contract.call(test_hash).errors)
    end

    it 'produces an appropriate error if sorting is negative' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:sorting] = -1

      assert_equal({ sorting: ['must be greater than 0'] }, external_source_download_contract.call(test_hash).errors.to_h)
    end

    it 'fails if download_item has no source_type specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup

      assert_predicate(external_source_download_contract.call(test_hash.except(:source_type)), :present?)
    end

    it 'produces an appropriate error if no source_type is specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup

      assert_empty(external_source_download_contract.call(test_hash.except(:source_type)).errors)
    end

    it 'fails if download_item has no endpoint specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup

      assert_predicate(external_source_download_contract.call(test_hash.except(:source_type)), :present?)
    end

    it 'produces an appropriate error if no endpoint is specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup

      assert_empty(external_source_download_contract.call(test_hash.except(:endpoint)).errors)
    end

    it 'produces an appropriate error if endpoint is not a valid class_name' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:endpoint] = 'DataCycleCore::XXX'

      assert_equal({ endpoint: ['must be a valid Ruby class'] }, external_source_download_contract.call(test_hash).errors.to_h)
    end

    it 'fails if download_item has no download_strategy specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup

      assert_predicate(external_source_download_contract.call(test_hash.except(:download_strategy)), :present?)
    end

    it 'produces an appropriate error if no download_strategy is specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup

      assert_equal({ nil => [':import_strategy or :download_strategy must be defined'] }, external_source_download_contract.call(test_hash.except(:download_strategy)).errors.to_h)
    end

    it 'produces an appropriate error if download_strategy is not a module' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:download_strategy] = 'DataCycleCore::XXX'

      assert_equal({ download_strategy: ['must be a valid Ruby module'] }, external_source_download_contract.call(test_hash).errors.to_h)
    end

    it 'produces an appropriate error if logging_strategy is not a module' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:logging_strategy] = 'DataCycleCore::XXX'

      assert_equal({ logging_strategy: ['the string given does not specify a valid logging class.'] }, external_source_download_contract.call(test_hash).errors.to_h)
    end

    it 'produces an appropriate error if sorting is negative for an import_item' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:sorting] = -1

      assert_equal({ sorting: ['must be greater than 0'] }, external_source_import_contract.call(test_hash).errors.to_h)
    end

    it 'fails if import_item has no source_type specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup

      assert_predicate(external_source_import_contract.call(test_hash.except(:source_type)), :present?)
    end

    it 'produces an appropriate error if no source_type is specified for an import_item' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup

      assert_empty(external_source_import_contract.call(test_hash.except(:source_type)).errors)
    end

    it 'fails if import_item has no import_strategy specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup

      assert_predicate(external_source_import_contract.call(test_hash.except(:import_strategy)), :present?)
    end

    it 'produces an appropriate error if no import_strategy is specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup

      assert_equal({ nil => [':import_strategy or :download_strategy must be defined'] }, external_source_import_contract.call(test_hash.except(:import_strategy)).errors.to_h)
    end

    it 'produces an appropriate error if import_strategy is not a valid class_name' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:import_strategy] = 'DataCycleCore::XXX'

      assert_equal({ import_strategy: ['must be a valid Ruby module'] }, external_source_import_contract.call(test_hash).errors.to_h)
    end

    it 'fails if import_item has no data_template specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup

      assert_predicate(external_source_import_contract.call(test_hash.except(:data_template)), :present?)
    end

    it 'check that data_template is optional' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup

      assert_empty(external_source_import_contract.call(test_hash.except(:data_template)).errors)
    end

    it 'produces an appropriate config with full paths' do
      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        assert_kind_of(Hash, data)

        next if data['name'] != 'Remote-System-with-partial-paths'

        assert_equal(
          'DataCycleCore::Generic::Csv::Transformations',
          data.dig('default_options', 'transformations')
        )
        assert_equal(
          'DataCycleCore::Generic::Csv::Endpoint',
          data.dig('config', 'download_config', 'images', 'endpoint')
        )
        assert_equal(
          'DataCycleCore::Generic::Common::DownloadFunctions',
          data.dig('config', 'download_config', 'images', 'download_strategy')
        )
        assert_equal(
          'DataCycleCore::Generic::Common::ImportTags',
          data.dig('config', 'import_config', 'images', 'import_strategy')
        )
        assert_equal(
          'DataCycleCore::Generic::Common::ImportContents',
          data.dig('config', 'import_config', 'places', 'import_strategy')
        )
        assert_equal(
          'DataCycleCore::Generic::Common::ImportContents',
          data.dig('config', 'import_config', 'events', 'import_strategy')
        )
      end
    end

    it 'loads the correct config according to the current environment' do
      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        assert_kind_of(Hash, data)

        next if data['identifier'] != 'test-system-1'

        assert_predicate(data['credentials'], :present?)
        assert_equal('LOCAL_HOST', data.dig('credentials', 'host'))
        assert(data.dig('config', 'download_config').key?('videos'))
        assert_not(data.dig('config', 'download_config').key?('images'))
        assert(data.dig('config', 'import_config').key?('videos'))
        assert_not(data.dig('config', 'import_config').key?('images'))
      end
    end
  end

  describe 'extends mechanism for external_systems' do
    let(:import_path) do
      Rails.root.join('..', 'fixtures', 'external_systems')
    end

    it "extends a base system's credentials" do
      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        assert(data.is_a?(Hash))

        next if data['identifier'] != 'extended-system'

        assert_predicate(data['credentials'], :present?)
        assert_equal('BASE_HOST', data.dig('credentials', 'host'))
        assert_equal('BASE_TOKEN', data.dig('credentials', 'token'))
        assert_equal('v1', data.dig('credentials', 'api_version'))
      end
    end

    it "extends a base system's default_options" do
      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        assert(data.is_a?(Hash))

        next if data['identifier'] != 'extended-system'

        assert_equal('DataCycleCore::Generic::Common::Transformations', data.dig('default_options', 'transformations'))
        assert_predicate(data.dig('default_options', 'export'), :present?)
        assert_equal('https://base.example.com', data.dig('default_options', 'export', 'external_url'))
      end
    end

    it "extends a base system's module_base" do
      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        assert(data.is_a?(Hash))

        next if data['identifier'] != 'extended-system'

        assert_equal('DataCycleCore::Generic::Common', data['module_base'])
      end
    end

    it "extends a base system's download_config" do
      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        assert(data.is_a?(Hash))

        next if data['identifier'] != 'extended-system'

        assert_predicate(data['config'], :present?)

        assert_predicate(data.dig('config', 'download_config'), :present?)
        assert_predicate(data.dig('config', 'download_config', 'images'), :present?)
        assert_equal(1, data.dig('config', 'download_config', 'images', 'sorting'))
        assert_equal('contents', data.dig('config', 'download_config', 'images', 'source_type'))
        assert_equal('DataCycleCore::Generic::Csv::Endpoint', data.dig('config', 'download_config', 'images', 'endpoint'))
        assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', data.dig('config', 'download_config', 'images', 'download_strategy'))

        assert_predicate(data.dig('config', 'download_config', 'places'), :present?)
        assert_equal(2, data.dig('config', 'download_config', 'places', 'sorting'))
        assert_equal('overwritten-source-type', data.dig('config', 'download_config', 'places', 'source_type'))
        assert_equal('DataCycleCore::Generic::Csv::Endpoint', data.dig('config', 'download_config', 'places', 'endpoint'))
        assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', data.dig('config', 'download_config', 'places', 'download_strategy'))
      end
    end

    it "extends a base system's import_config" do
      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        assert(data.is_a?(Hash))

        next if data['identifier'] != 'extended-system'

        assert_predicate(data['config'], :present?)

        assert_predicate(data.dig('config', 'import_config'), :present?)
        assert_predicate(data.dig('config', 'import_config', 'images'), :present?)
        assert_equal(1, data.dig('config', 'import_config', 'images', 'sorting'))
        assert_equal('images', data.dig('config', 'import_config', 'images', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::ImportTags', data.dig('config', 'import_config', 'images', 'import_strategy'))
        assert_equal('Base - Tags', data.dig('config', 'import_config', 'images', 'tree_label'))

        assert_predicate(data.dig('config', 'import_config', 'places'), :present?)
        assert_equal(2, data.dig('config', 'import_config', 'places', 'sorting'))
        assert_equal('places', data.dig('config', 'import_config', 'places', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::ImportContents', data.dig('config', 'import_config', 'places', 'import_strategy'))
        assert_predicate(data.dig('config', 'import_config', 'places', 'main_content'), :present?)
        assert_equal('Place', data.dig('config', 'import_config', 'places', 'main_content', 'template'))
        assert_equal('to_place', data.dig('config', 'import_config', 'places', 'main_content', 'transformation'))
      end
    end

    it 'correctly applies module_base inheritance with partial paths' do
      extended_system = nil

      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        extended_system = data if data['identifier'] == 'extended-system'
      end

      assert_predicate(extended_system, :present?)

      assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', extended_system.dig('config', 'download_config', 'images', 'download_strategy'))
      assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', extended_system.dig('config', 'download_config', 'places', 'download_strategy'))
      assert_equal('DataCycleCore::Generic::Common::ImportTags', extended_system.dig('config', 'import_config', 'images', 'import_strategy'))
      assert_equal('DataCycleCore::Generic::Common::ImportContents', extended_system.dig('config', 'import_config', 'places', 'import_strategy'))
    end

    it "overrides a base system's credentials" do
      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do
        assert(data.is_a?(Hash))

        next if data['identifier'] != 'override-system'

        assert_equal('BASE_HOST', data.dig('credentials', 'host'))
        assert_equal('OVERRIDE_TOKEN', data.dig('credentials', 'token'))
        assert_equal('v2', data.dig('credentials', 'api_version'))
        assert_equal('OVERRIDE_USER', data.dig('credentials', 'username'))
      end
    end

    it "overrides a base system's default_options" do
      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do
        assert(data.is_a?(Hash))

        next if data['identifier'] != 'override-system'

        assert_equal('DataCycleCore::Generic::Common::Transformations', data.dig('default_options', 'transformations'))
        assert_predicate(data.dig('default_options', 'export'), :present?)
        assert_equal('https://override.example.com', data.dig('default_options', 'export', 'external_url'))
        assert_equal('json', data.dig('default_options', 'export', 'format'))
      end
    end

    it "overrides a base system's download_config" do
      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        assert(data.is_a?(Hash))

        next if data['identifier'] != 'override-system'

        assert_predicate(data['config'], :present?)

        assert_predicate(data.dig('config', 'download_config'), :present?)
        assert_predicate(data.dig('config', 'download_config', 'images'), :present?)
        assert_equal(1, data.dig('config', 'download_config', 'images', 'sorting'))
        assert_equal('images', data.dig('config', 'download_config', 'images', 'source_type'))
        assert_equal('DataCycleCore::Generic::Csv::Endpoint', data.dig('config', 'download_config', 'images', 'endpoint'))
        assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', data.dig('config', 'download_config', 'images', 'download_strategy'))

        assert_predicate(data.dig('config', 'download_config', 'places'), :present?)
        assert_equal(2, data.dig('config', 'download_config', 'places', 'sorting'))
        assert_equal('places', data.dig('config', 'download_config', 'places', 'source_type'))
        assert_equal('DataCycleCore::Generic::Csv::Endpoint', data.dig('config', 'download_config', 'places', 'endpoint'))
        assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', data.dig('config', 'download_config', 'places', 'download_strategy'))
      end
    end

    it "overrides a base system's import_config" do
      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        assert(data.is_a?(Hash))

        next if data['identifier'] != 'override-system'

        assert_predicate(data['config'], :present?)

        assert_predicate(data.dig('config', 'import_config'), :present?)
        assert_predicate(data.dig('config', 'import_config', 'images'), :present?)
        assert_equal(1, data.dig('config', 'import_config', 'images', 'sorting'))
        assert_equal('images', data.dig('config', 'import_config', 'images', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::ImportTags', data.dig('config', 'import_config', 'images', 'import_strategy'))
        assert_equal('Override - Tags', data.dig('config', 'import_config', 'images', 'tree_label'))

        assert_predicate(data.dig('config', 'import_config', 'places'), :present?)
        assert_equal(2, data.dig('config', 'import_config', 'places', 'sorting'))
        assert_equal('places', data.dig('config', 'import_config', 'places', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::ImportContents', data.dig('config', 'import_config', 'places', 'import_strategy'))
        assert_predicate(data.dig('config', 'import_config', 'places', 'main_content'), :present?)
        assert_equal('Place', data.dig('config', 'import_config', 'places', 'main_content', 'template'))
        assert_equal('to_place', data.dig('config', 'import_config', 'places', 'main_content', 'transformation'))

        assert_predicate(data.dig('config', 'import_config'), :present?)
        assert_predicate(data.dig('config', 'import_config', 'events'), :present?)
        assert_equal(3, data.dig('config', 'import_config', 'events', 'sorting'))
        assert_equal('events', data.dig('config', 'import_config', 'events', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::ImportContents', data.dig('config', 'import_config', 'events', 'import_strategy'))
      end
    end

    it 'does not include \'extends\' key in final data' do
      extended_system = nil

      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        extended_system = data if data['identifier'] == 'extended-system'
      end

      assert_predicate(extended_system, :present?)
      assert_not(extended_system.key?('extends'))
    end

    it 'delays extending until base system is processed' do
      extended_system = nil

      errors = DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        extended_system = data if data['identifier'] == 'a-extended-system'
      end

      assert_empty(errors)
      assert_predicate(extended_system, :present?)
    end

    it 'extends sorting' do
      extended_system = nil

      DataCycleCore::MasterData::ImportExternalSystems.load_all(paths: import_path) do |data|
        extended_system = data if data['identifier'] == 'extended-system'
      end

      assert_predicate(extended_system, :present?)

      assert_equal(1, extended_system.dig('config', 'import_config', 'images', 'sorting'))
      assert_equal(2, extended_system.dig('config', 'import_config', 'places', 'sorting'))
    end

    it 'merges systems with same name and identifier, i.e. simulating different submodules' do
      Dir.mktmpdir do |dir|
        base = <<~YAML
          ---
          name: Same-System
          identifier: same-system
          config:
            download_config:
              images:
                source_type: images
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        override = <<~YAML
          ---
          name: Same-System
          identifier: same-system
          extends: same-system
          config:
            download_config:
              places:
                source_type: places
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        File.write(File.join(dir, 'base.yml'), base)
        File.write(File.join(dir, 'override.yml'), override)

        loaded = []
        errors = subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :blank?)
        assert_equal(1, loaded.length)
        data = loaded.first

        assert_equal('same-system', data['identifier'])
        assert_equal('Same-System', data['name'])
        assert_equal('images', data.dig('config', 'download_config', 'images', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', data.dig('config', 'download_config', 'images', 'download_strategy'))
        assert_equal('places', data.dig('config', 'download_config', 'places', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', data.dig('config', 'download_config', 'places', 'download_strategy'))
        assert_not(data.key?('extends'))
      end
    end

    it 'merges systems with same name and identifier but remove one of the download_steps' do
      Dir.mktmpdir do |dir|
        base = <<~YAML
          ---
          name: Same-System
          identifier: same-system
          config:
            download_config:
              images:
                source_type: images
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
              places:
                source_type: places
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        override = <<~YAML
          ---
          name: Same-System
          identifier: same-system
          extends: same-system
          config:
            download_config:
              places: ~
        YAML

        File.write(File.join(dir, 'base.yml'), base)
        File.write(File.join(dir, 'override.yml'), override)

        loaded = []
        errors = subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :blank?)
        assert_equal(1, loaded.length)
        data = loaded.first

        assert_equal('same-system', data['identifier'])
        assert_equal('Same-System', data['name'])
        assert_equal('images', data.dig('config', 'download_config', 'images', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', data.dig('config', 'download_config', 'images', 'download_strategy'))

        assert_not(data.dig('config', 'download_config', 'places').present?)
        assert_not(data.key?('extends'))
      end
    end
  end

  describe 'abstract external_systems' do
    let(:base_yaml) do
      <<~YAML
        ---
        name: Abstract-Base
        identifier: abstract-base
        abstract: true
        credentials:
          host: ABSTRACT_HOST
          token: ABSTRACT_TOKEN
        config:
          download_config:
            images:
              source_type: images
              download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
      YAML
    end

    let(:concrete_child_yaml) do
      <<~YAML
        ---
        name: Concrete-Child
        identifier: concrete-child
        extends: abstract-base
        config:
          download_config:
            places:
              source_type: places
              download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
      YAML
    end

    let(:abstract_child_yaml) do
      <<~YAML
        ---
        name: Concrete-Abstract-Child
        identifier: concrete-abstract-child
        abstract: true
        extends: abstract-base
        config:
          download_config:
            events:
              source_type: events
              download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
      YAML
    end

    it 'excludes abstract external_systems from yielded systems' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'base.yml'), base_yaml)
        File.write(File.join(dir, 'child.yml'), concrete_child_yaml)

        loaded = []
        errors = subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :blank?)
        assert_nil(loaded.find { |d| d['identifier'] == 'abstract-base' })
      end
    end

    it 'excludes systems that explicitly mark themselves abstract even when extending another' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'base.yml'), base_yaml)
        File.write(File.join(dir, 'abstract_child.yml'), abstract_child_yaml)

        loaded = []
        errors = subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :blank?)
        assert_nil(loaded.find { |d| d['identifier'] == 'concrete-abstract-child' })
      end
    end

    it 'includes concrete children of abstract external_systems' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'base.yml'), base_yaml)
        File.write(File.join(dir, 'child.yml'), concrete_child_yaml)

        loaded = []
        errors = subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :blank?)
        assert_predicate(loaded.find { |d| d['identifier'] == 'concrete-child' }, :present?)
      end
    end

    it 'inherits properties from the abstract base external_system' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'base.yml'), base_yaml)
        File.write(File.join(dir, 'child.yml'), concrete_child_yaml)

        loaded = []
        subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        child = loaded.find { |d| d['identifier'] == 'concrete-child' }

        assert_equal('ABSTRACT_HOST', child.dig('credentials', 'host'))
        assert_equal('ABSTRACT_TOKEN', child.dig('credentials', 'token'))
        assert_predicate(child.dig('config', 'download_config', 'images'), :present?)
        assert_predicate(child.dig('config', 'download_config', 'places'), :present?)
      end
    end

    it 'does not produce errors when an abstract external_system is present' do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, 'base.yml'), base_yaml)
        File.write(File.join(dir, 'child.yml'), concrete_child_yaml)

        loaded = []
        errors = subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :blank?)
        assert_equal(1, loaded.length)
      end
    end

    it 'does not propagate the abstract flag when an external_system extends itself' do
      Dir.mktmpdir do |dir|
        base = <<~YAML
          ---
          name: Abstract-Self-Extend
          identifier: abstract-self-extend
          abstract: true
          credentials:
            host: BASE_HOST
          config:
            download_config:
              images:
                source_type: images
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        override = <<~YAML
          ---
          name: Abstract-Self-Extend
          identifier: abstract-self-extend
          extends: abstract-self-extend
          config:
            download_config:
              places:
                source_type: places
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        File.write(File.join(dir, 'base.yml'), base)
        File.write(File.join(dir, 'override.yml'), override)

        loaded = []
        errors = subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :blank?)
        assert_equal(1, loaded.length)
        assert_equal('abstract-self-extend', loaded.first['identifier'])
      end
    end

    it 'does not error for abstract system with missing base that is never extended' do
      Dir.mktmpdir do |dir|
        abstract_with_missing_base = <<~YAML
          ---
          name: Abstract-Missing-Base
          identifier: abstract-missing-base
          abstract: true
          extends: non-existent-base
          config:
            download_config:
              images:
                source_type: images
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        File.write(File.join(dir, 'abstract.yml'), abstract_with_missing_base)

        loaded = []
        errors = subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_empty(errors)
        assert_empty(loaded)
      end
    end

    it 'errors when concrete system extends abstract system with missing base' do
      Dir.mktmpdir do |dir|
        abstract_with_missing_base = <<~YAML
          ---
          name: Abstract-Missing-Base
          identifier: abstract-missing-base
          abstract: true
          extends: non-existent-base
          config:
            download_config:
              images:
                source_type: images
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        concrete_extends_abstract = <<~YAML
          ---
          name: Concrete-Extends-Abstract
          identifier: concrete-extends-abstract
          extends: abstract-missing-base
          config:
            download_config:
              places:
                source_type: places
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        File.write(File.join(dir, 'abstract.yml'), abstract_with_missing_base)
        File.write(File.join(dir, 'concrete.yml'), concrete_extends_abstract)

        loaded = []
        errors = subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :present?)
        assert(errors.any? { |error| error.include?('missing') || error.include?('Missing') })
        assert_empty(loaded)
      end
    end

    it 'errors when non-abstract system extends missing base' do
      Dir.mktmpdir do |dir|
        concrete_with_missing_base = <<~YAML
          ---
          name: Concrete-Missing-Base
          identifier: concrete-missing-base
          extends: non-existent-base
          config:
            download_config:
              images:
                source_type: images
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        File.write(File.join(dir, 'concrete.yml'), concrete_with_missing_base)

        loaded = []
        errors = subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :present?)
        assert(errors.any? { |error| error.include?('missing') || error.include?('Missing') })
        assert_empty(loaded)
      end
    end

    it 'provides informative error when non-abstract extends abstract that has missing base' do
      Dir.mktmpdir do |dir|
        abstract_missing_base = <<~YAML
          ---
          name: Abstract-Middle
          identifier: abstract-middle
          abstract: true
          extends: non-existent-base
          config:
            download_config:
              images:
                source_type: images
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        concrete_extends_abstract = <<~YAML
          ---
          name: Concrete-Top
          identifier: concrete-top
          extends: abstract-middle
          config:
            download_config:
              places:
                source_type: places
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        File.write(File.join(dir, 'abstract.yml'), abstract_missing_base)
        File.write(File.join(dir, 'concrete.yml'), concrete_extends_abstract)

        loaded = []
        errors = subject.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :present?)
        assert_equal(1, errors.length)
        assert(errors.first.include?('concrete-top') || errors.first.include?('Concrete-Top'))
        assert_includes(errors.first, 'abstract-middle')
        assert(errors.first.include?('skipped') || errors.first.include?('abstract system was skipped'))
        assert_empty(loaded)
      end
    end
  end

  describe '\'position\' in external_systems config' do
    let(:importer) { subject }

    it 'reorders steps with \'position\' \'after\' and rewrites sorting' do
      data = YAML.safe_load(<<~YAML)
        ---
        name: Position-After
        identifier: position-after
        config:
          download_config:
            images:
              sorting: 3
              source_type: images
              download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
              position:
                after: places
            places:
              sorting: 1
              source_type: places
              download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
            events:
              sorting: 2
              source_type: events
              download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
      YAML

      importer.transform_data!(data)

      ordered_keys = data.dig('config', 'download_config').keys

      assert_equal(['places', 'images', 'events'], ordered_keys)
      assert_equal(1, data.dig('config', 'download_config', 'places', 'sorting'))
      assert_equal(2, data.dig('config', 'download_config', 'images', 'sorting'))
      assert_equal(3, data.dig('config', 'download_config', 'events', 'sorting'))
    end

    it 'reorders steps with \'position\' \'before\' and rewrites sorting' do
      data = YAML.safe_load(<<~YAML)
        ---
        name: Position-Before
        identifier: position-before
        config:
          import_config:
            images:
              sorting: 2
              source_type: images
              import_strategy: DataCycleCore::Generic::Common::ImportTags
            events:
              sorting: 3
              source_type: events
              import_strategy: DataCycleCore::Generic::Common::ImportContents
              position:
                before: images
            places:
              sorting: 1
              source_type: places
              import_strategy: DataCycleCore::Generic::Common::ImportContents
      YAML

      importer.transform_data!(data)

      ordered_keys = data.dig('config', 'import_config').keys

      assert_equal(['events', 'images', 'places'], ordered_keys)
      assert_equal(1, data.dig('config', 'import_config', 'events', 'sorting'))
      assert_equal(2, data.dig('config', 'import_config', 'images', 'sorting'))
      assert_equal(3, data.dig('config', 'import_config', 'places', 'sorting'))
    end

    it 'honors chained \'position\' dependencies' do
      data = YAML.safe_load(<<~YAML)
        ---
        name: Position-Chain
        identifier: position-chain
        config:
          import_config:
            images:
              source_type: images
              import_strategy: DataCycleCore::Generic::Common::ImportTags
              position:
                after: places
            events:
              source_type: events
              import_strategy: DataCycleCore::Generic::Common::ImportContents
              position:
                after: images
            places:
              source_type: places
              import_strategy: DataCycleCore::Generic::Common::ImportContents
      YAML

      importer.transform_data!(data)

      ordered_keys = data.dig('config', 'import_config').keys

      assert_equal(['places', 'images', 'events'], ordered_keys)
      assert_equal(1, data.dig('config', 'import_config', 'places', 'sorting'))
      assert_equal(2, data.dig('config', 'import_config', 'images', 'sorting'))
      assert_equal(3, data.dig('config', 'import_config', 'events', 'sorting'))
    end

    it 'fails when \'position\' has both \'before\' and \'after\'' do
      data = YAML.safe_load(<<~YAML)
        ---
        name: Position-Conflict
        identifier: position-conflict
        config:
          import_config:
            images:
              sorting: 1
              source_type: images
              import_strategy: DataCycleCore::Generic::Common::ImportTags
              position:
                before: places
                after: events
            places:
              sorting: 2
              source_type: places
              import_strategy: DataCycleCore::Generic::Common::ImportContents
            events:
              sorting: 3
              source_type: events
              import_strategy: DataCycleCore::Generic::Common::ImportContents
      YAML

      errors = importer.validate(data)

      assert_predicate(errors, :present?)
      assert(errors.any? { |error| error.include?("position must be either 'before' or 'after', not both!") })
    end

    it 'fails when \'position\' references a missing target' do
      data = YAML.safe_load(<<~YAML)
        ---
        name: Position-Missing-Target
        identifier: position-missing-target
        config:
          download_config:
            images:
              sorting: 1
              source_type: images
              download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
              position:
                after: does_not_exist
            places:
              sorting: 2
              source_type: places
              download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
      YAML

      errors = importer.validate(data)

      assert_predicate(errors, :present?)
      assert(errors.any? { |error| error.include?("attribute 'does_not_exist' missing for position: { after: does_not_exist }") })
    end

    it 'fails when \'position\' rules create a cycle' do
      data = YAML.safe_load(<<~YAML)
        ---
        name: Position-Cycle
        identifier: position-cycle
        config:
          import_config:
            images:
              sorting: 1
              source_type: images
              import_strategy: DataCycleCore::Generic::Common::ImportTags
              position:
                after: places
            places:
              sorting: 2
              source_type: places
              import_strategy: DataCycleCore::Generic::Common::ImportContents
              position:
                after: images
      YAML

      errors = importer.validate(data)

      assert_predicate(errors, :present?)
      assert(errors.any? { |error| error.include?('cycle') || error.include?('position cycle detected') })
    end

    it 'applies \'position\' from overrides against base config' do
      Dir.mktmpdir do |dir|
        base = <<~YAML
          ---
          name: Base-Position
          identifier: base-position
          config:
            download_config:
              images:
                sorting: 1
                source_type: images
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
              places:
                sorting: 2
                source_type: places
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
              events:
                sorting: 3
                source_type: events
                download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
        YAML

        override = <<~YAML
          ---
          name: Override-Position
          identifier: override-position
          extends: base-position
          config:
            download_config:
              events:
                position:
                  before: images
        YAML

        File.write(File.join(dir, 'base.yml'), base)
        File.write(File.join(dir, 'override.yml'), override)

        loaded = []
        errors = importer.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :blank?)
        assert_equal(2, loaded.length) # TODO: same identifier in both base and override
        data = loaded.find { |item| item['identifier'] == 'override-position' }

        assert_predicate(data, :present?)

        ordered_keys = data.dig('config', 'download_config').keys

        assert_equal(['events', 'images', 'places'], ordered_keys)
        assert_equal(1, data.dig('config', 'download_config', 'events', 'sorting'))
        assert_equal(2, data.dig('config', 'download_config', 'images', 'sorting'))
        assert_equal(3, data.dig('config', 'download_config', 'places', 'sorting'))

        assert_equal('events', data.dig('config', 'download_config', 'events', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', data.dig('config', 'download_config', 'events', 'download_strategy'))
        assert_equal('images', data.dig('config', 'download_config', 'images', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', data.dig('config', 'download_config', 'images', 'download_strategy'))
        assert_equal('places', data.dig('config', 'download_config', 'places', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::DownloadFunctions', data.dig('config', 'download_config', 'places', 'download_strategy'))
      end
    end

    it 'positions newly added keys from overrides' do
      Dir.mktmpdir do |dir|
        base = <<~YAML
          ---
          name: Base-New-Key
          identifier: base-new-key
          config:
            import_config:
              images:
                source_type: images
                import_strategy: DataCycleCore::Generic::Common::ImportTags
              places:
                source_type: places
                import_strategy: DataCycleCore::Generic::Common::ImportContents
        YAML

        override = <<~YAML
          ---
          name: Override-New-Key
          identifier: override-new-key
          extends: base-new-key
          config:
            import_config:
              reports:
                source_type: reports
                import_strategy: DataCycleCore::Generic::Common::ImportContents
                position:
                  after: places
        YAML

        File.write(File.join(dir, 'base.yml'), base)
        File.write(File.join(dir, 'override.yml'), override)

        loaded = []
        errors = importer.load_all(paths: Pathname.new(dir)) { |data| loaded << data }

        assert_predicate(errors, :blank?)
        assert_equal(2, loaded.length) # TODO: same identifier in both base and override
        data = loaded.find { |item| item['identifier'] == 'override-new-key' }

        assert_predicate(data, :present?)

        ordered_keys = data.dig('config', 'import_config').keys

        assert_equal(['images', 'places', 'reports'], ordered_keys)
        assert_equal(1, data.dig('config', 'import_config', 'images', 'sorting'))
        assert_equal(2, data.dig('config', 'import_config', 'places', 'sorting'))
        assert_equal(3, data.dig('config', 'import_config', 'reports', 'sorting'))

        assert_equal('reports', data.dig('config', 'import_config', 'reports', 'source_type'))
        assert_equal('DataCycleCore::Generic::Common::ImportContents', data.dig('config', 'import_config', 'reports', 'import_strategy'))
        assert_equal({ 'after' => 'places' }, data.dig('config', 'import_config', 'reports', 'position'))
      end
    end

    it 'rewrites sorting when \'position\' is present' do
      data = YAML.safe_load(<<~YAML)
        ---
        name: Position-Rewrite-Sorting
        identifier: position-rewrite-sorting
        config:
          download_config:
            images:
              sorting: 9
              source_type: images
              download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
              position:
                after: places
            places:
              sorting: 1
              source_type: places
              download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
            events:
              sorting: 7
              source_type: events
              download_strategy: DataCycleCore::Generic::Common::DownloadFunctions
      YAML

      importer.transform_data!(data)

      ordered_keys = data.dig('config', 'download_config').keys

      assert_equal(['places', 'images', 'events'], ordered_keys)
      assert_equal(1, data.dig('config', 'download_config', 'places', 'sorting'))
      assert_equal(2, data.dig('config', 'download_config', 'images', 'sorting'))
      assert_equal(3, data.dig('config', 'download_config', 'events', 'sorting'))
    end

    it 'keeps insertion order when no \'position\' is provided' do
      data = YAML.safe_load(<<~YAML)
        ---
        name: Position-None
        identifier: position-none
        config:
          import_config:
            images:
              sorting: 1
              source_type: images
              import_strategy: DataCycleCore::Generic::Common::ImportTags
            places:
              sorting: 2
              source_type: places
              import_strategy: DataCycleCore::Generic::Common::ImportContents
            events:
              sorting: 3
              source_type: events
              import_strategy: DataCycleCore::Generic::Common::ImportContents
      YAML

      importer.transform_data!(data)

      ordered_keys = data.dig('config', 'import_config').keys

      assert_equal(['images', 'places', 'events'], ordered_keys)
      assert_equal(1, data.dig('config', 'import_config', 'images', 'sorting'))
      assert_equal(2, data.dig('config', 'import_config', 'places', 'sorting'))
      assert_equal(3, data.dig('config', 'import_config', 'events', 'sorting'))
    end
  end

  describe 'endpoint method validation' do
    # The download dispatch calls `endpoint.send(endpoint_method || source_type)`,
    # so the derived method must exist on the endpoint class. DataCycleCore::Generic::Csv::Endpoint
    # is used here because it is one of the few endpoints available in the gem's test
    # environment; it exposes the instance method `csv_categories`.
    let(:step_contract) { subject::ExternalSystemStepContract.new }

    let(:base_step) do
      {
        sorting: 1,
        endpoint: 'DataCycleCore::Generic::Csv::Endpoint',
        download_strategy: 'DataCycleCore::Generic::Common::DownloadFunctions'
      }
    end

    it 'passes when the endpoint defines the method derived from source_type' do
      step = base_step.merge(source_type: 'csv_categories')

      Rails.env.stub(:test?, false) do
        assert_empty(step_contract.call(step).errors)
      end
    end

    it 'fails when the endpoint does not define the method derived from source_type' do
      step = base_step.merge(source_type: 'csv_category')

      Rails.env.stub(:test?, false) do
        errors = step_contract.call(step).errors.to_h

        assert(errors.key?(:endpoint))
        assert(errors[:endpoint].any? { |e| e.include?('csv_category') })
      end
    end

    it 'derives the method from endpoint_method when present, ignoring source_type' do
      step = base_step.merge(source_type: 'csv_category', endpoint_method: 'csv_categories')

      Rails.env.stub(:test?, false) do
        assert_empty(step_contract.call(step).errors)
      end
    end

    it 'fails when endpoint_method does not exist even if source_type would match' do
      step = base_step.merge(source_type: 'csv_categories', endpoint_method: 'missing_method')

      Rails.env.stub(:test?, false) do
        errors = step_contract.call(step).errors.to_h

        assert(errors.key?(:endpoint))
        assert(errors[:endpoint].any? { |e| e.include?('missing_method') })
      end
    end

    it 'leaves class existence to the :ruby_class? predicate when the endpoint cannot be loaded' do
      step = base_step.merge(source_type: 'csv_category', endpoint: 'DataCycleCore::DoesNotExist')

      Rails.env.stub(:test?, false) do
        assert_equal(['must be a valid Ruby class'], step_contract.call(step).errors.to_h[:endpoint])
      end
    end

    it 'does not run the endpoint method check in the test environment' do
      step = base_step.merge(source_type: 'csv_category')

      assert_empty(step_contract.call(step).errors)
    end

    it 'reports the mismatch through .validate with a descriptive path' do
      data = {
        'name' => 'Endpoint-Method-Mismatch',
        'identifier' => 'endpoint-method-mismatch',
        'config' => {
          'download_config' => {
            'providers' => {
              'sorting' => 1,
              'source_type' => 'csv_category',
              'endpoint' => 'DataCycleCore::Generic::Csv::Endpoint',
              'download_strategy' => 'DataCycleCore::Generic::Common::DownloadFunctions'
            }
          }
        }
      }

      Rails.env.stub(:test?, false) do
        errors = subject.validate(data)

        assert(errors.any? { |e| e.include?('config.download_config.providers.endpoint') && e.include?('csv_category') })
      end
    end
  end
end
