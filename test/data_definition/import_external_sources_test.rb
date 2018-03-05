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
        'config' =>  {
          'download' => 'DataCycleCore::Generic::BatchDownload',
          'download_config' => {
            'images' => {
              'sorting' => 1,
              'source_type' => 'images',
              'endpoint' => 'DataCycleCore::Generic::MediaArchive::Endpoint',
              'download_strategy' => 'DataCycleCore::Generic::MediaArchive::Download',
              'logging_strategy' => 'DataCycleCore::Generic::Logger::Console.new(\'download\')'
            },
            'videos' => {
              'sorting' => 2,
              'source_type' => 'videos',
              'endpoint' => 'DataCycleCore::Generic::MediaArchive::Endpoint',
              'download_strategy' => 'DataCycleCore::Generic::MediaArchive::Download',
              'logging_strategy' => 'DataCycleCore::Generic::Logger::Console.new(\'download\')'
            }
          },
          'import' => 'DataCycleCore::Generic::BatchImport',
          'import_config' => {
            'images' => {
              'sorting' => 1,
              'source_type' => 'images',
              'import_strategy' => 'DataCycleCore::Generic::MediaArchive::Import',
              'data_template' => 'Bild',
              'target_type' => 'DataCycleCore::CreativeWork',
              'logging_strategy' => 'DataCycleCore::Generic::Logger::Console.new(\'import\')'
            },
            'videos' => {
              'sorting' => 2,
              'source_type' => 'videos',
              'import_strategy' => 'DataCycleCore::Generic::MediaArchive::Import',
              'data_template' => 'Video', 'target_type' => 'DataCycleCore::CreativeWork',
              'logging_strategy' => 'DataCycleCore::Generic::Logger::Console.new(\'import\')'
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
      assert !Dir[DataCycleCore.external_sources_path + '*.yml'].count.zero?
    end

    it 'successfully validates the test config' do
      assert subject.validate(external_source_config).blank?
    end
  end
end
