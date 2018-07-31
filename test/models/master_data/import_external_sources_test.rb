# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::MasterData::ImportExternalSources do
  subject do
    DataCycleCore::MasterData::ImportExternalSources
  end

  describe 'loaded external_sources_config' do
    let(:import_path) do
      Rails.root.join('congig', 'external_sources')
    end

    let(:external_source_config) do
      {
        'name' => 'test_config',
        'credentials' =>  {
          'end_point' => '/api/v1/media.json',
          'host' => 'https://views2.austria.info',
          'token' => 'NySHyubtwJNYcXWa38wVNvWwG8KWzLbq'
        },
        'default_options' => {
          'locales' => ['de']
        },
        'config' =>  {
          'download_config' => {
            'images' => {
              'sorting' => 1,
              'source_type' => 'images',
              'endpoint' => 'DataCycleCore::Generic::MediaArchive::Endpoint',
              'download_strategy' => 'DataCycleCore::Generic::MediaArchive::Download'
            },
            'videos' => {
              'sorting' => 2,
              'source_type' => 'videos',
              'endpoint' => 'DataCycleCore::Generic::MediaArchive::Endpoint',
              'download_strategy' => 'DataCycleCore::Generic::MediaArchive::Download'
            }
          },
          'import_config' => {
            'images' => {
              'sorting' => 2,
              'source_type' => 'images',
              'import_strategy' => 'DataCycleCore::Generic::MediaArchive::ImportImages',
              'transformations' => {
                'place' => {
                  'content_type' => 'DataCycleCore::Place',
                  'template' => 'Örtlichkeit'
                },
                'image' => {
                  'content_type' => 'DataCycleCore::CreativeWork',
                  'template' => 'Bild',
                  'place_template' => 'Örtlichkeit'
                }
              }
            },
            'videos' => {
              'sorting' => 3,
              'source_type' => 'videos',
              'import_strategy' => 'DataCycleCore::Generic::MediaArchive::ImportVideos',
              'transformations' => {
                'place' => {
                  'content_type' => 'DataCycleCore::Place',
                  'template' => 'Örtlichkeit'
                },
                'image' => {
                  'content_type' => 'DataCycleCore::CreativeWork',
                  'template' => 'Video',
                  'place_template' => 'Örtlichkeit'
                }
              }
            }
          },
          'api_strategy' => 'DataCycleCore::Api::MediaArchiveExternalSource'
        }
      }
    end

    it 'has a config path defined' do
      assert !DataCycleCore.external_sources_path.empty?
    end

    it 'has yml-files in the config path' do
      assert Dir[DataCycleCore.external_sources_path + '*.yml'].count.positive?
    end

    it 'successfully validates the test config' do
      assert subject.validate(external_source_config).blank?
    end

    it 'fails if no name is given' do
      assert subject.validate(external_source_config.except('name')).present?
    end

    it 'produces an appropriate error message if no name is given' do
      subject.validate(external_source_config.except('name')).must_equal({ name: ['is missing'] })
    end

    it 'fails if no credentials are given' do
      assert subject.validate(external_source_config.except('credentials')).present?
    end

    it 'produces an appropriate error message if no credentials are given' do
      subject.validate(external_source_config.except('credentials')).must_equal({ credentials: ['is missing'] })
    end

    it 'fails if no download_config is given' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('download_config')
      assert subject.validate(test_hash).present?
    end

    it 'produces an appropriate error message if no download_config is given' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('download_config')
      subject.validate(test_hash).must_equal({ config: { download_config: ['is missing'] } })
    end

    it 'fails if no import_config is given' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('import_config')
      assert subject.validate(test_hash).present?
    end

    it 'produces an appropriate error message if no import_config is given' do
      test_hash = external_source_config.deep_dup
      test_hash['config'] = test_hash['config'].except('import_config')
      subject.validate(test_hash).must_equal({ config: { import_config: ['is missing'] } })
    end

    it 'successfully validates a valid validate_download_item' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      subject.validate_download_item.call(test_hash).errors.must_equal({})
    end

    it 'produces an appropriate error if sorting is negative' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:sorting] = -1
      subject.validate_download_item.call(test_hash).errors.must_equal({ sorting: ['must be greater than 0'] })
    end

    it 'fails if download_item has no source_type specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      assert subject.validate_download_item.call(test_hash.except(:source_type)).present?
    end

    it 'produces an appropriate error if no source_type is specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      subject.validate_download_item.call(test_hash.except(:source_type)).errors.must_equal({ source_type: ['is missing'] })
    end

    it 'fails if download_item has no endpoint specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      assert subject.validate_download_item.call(test_hash.except(:source_type)).present?
    end

    it 'produces an appropriate error if no endpoint is specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      subject.validate_download_item.call(test_hash.except(:endpoint)).errors.must_equal({ endpoint: ['is missing'] })
    end

    it 'produces an appropriate error if endpoint is not a valid class_name' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:endpoint] = 'DataCycleCore::XXX'
      subject.validate_download_item.call(test_hash).errors.must_equal({ endpoint: ['the string given does not specify a valid ruby class.'] })
    end

    it 'fails if download_item has no download_strategy specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      assert subject.validate_download_item.call(test_hash.except(:download_strategy)).present?
    end

    it 'produces an appropriate error if no download_strategy is specified' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      subject.validate_download_item.call(test_hash.except(:download_strategy)).errors.must_equal({ download_strategy: ['is missing'] })
    end

    it 'produces an appropriate error if download_strategy is not a module' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:download_strategy] = 'DataCycleCore::XXX'
      subject.validate_download_item.call(test_hash).errors.must_equal({ download_strategy: ['the string given does not specify a valid ruby module.'] })
    end

    it 'produces an appropriate error if logging_strategy is not a module' do
      test_hash = external_source_config['config']['download_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:logging_strategy] = 'DataCycleCore::XXX'
      subject.validate_download_item.call(test_hash).errors.must_equal({ logging_strategy: ['the string given can not be evaluated.'] })
    end

    it 'produces an appropriate error if sorting is negative for an import_item' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:sorting] = -1
      subject.validate_import_item.call(test_hash).errors.must_equal({ sorting: ['must be greater than 0'] })
    end

    it 'fails if import_item has no source_type specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      assert subject.validate_import_item.call(test_hash.except(:source_type)).present?
    end

    it 'produces an appropriate error if no source_type is specified for an import_item' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      subject.validate_import_item.call(test_hash.except(:source_type)).errors.must_equal({ source_type: ['is missing'] })
    end

    it 'fails if import_item has no import_strategy specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      assert subject.validate_import_item.call(test_hash.except(:import_strategy)).present?
    end

    it 'produces an appropriate error if no import_strategy is specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      subject.validate_import_item.call(test_hash.except(:import_strategy)).errors.must_equal({ import_strategy: ['is missing'] })
    end

    it 'produces an appropriate error if import_strategy is not a valid class_name' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      test_hash[:import_strategy] = 'DataCycleCore::XXX'
      subject.validate_import_item.call(test_hash).errors.must_equal({ import_strategy: ['the string given does not specify a valid ruby module.'] })
    end

    it 'fails if import_item has no data_template specified' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      assert subject.validate_import_item.call(test_hash.except(:data_template)).present?
    end

    it 'check that data_template is optional' do
      test_hash = external_source_config['config']['import_config']['images'].deep_symbolize_keys.deep_dup
      subject.validate_import_item.call(test_hash.except(:data_template)).errors.must_equal({})
    end
  end
end
