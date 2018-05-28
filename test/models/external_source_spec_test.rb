require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'

describe DataCycleCore::ExternalSource do
  subject do
    DataCycleCore::ExternalSource.new(
      name: 'test_source',
      credentials: {
        host: 'https://maps.googleapis.com/',
        end_point: 'maps/api/place/',
        key: 'testkey'
      },
      config: {
        download: 'DataCycleCore::Generic::BatchDownload',
        download_config: {
          places: {
            sorting: 1,
            source_type: 'places',
            endpoint: 'DataCycleCore::Generic::GooglePlaces::Endpoint',
            download_strategy: 'DataCycleCore::Generic::GooglePlaces::Download',
            logging_strategy: 'DataCycleCore::Generic::Logger::LogFile.new("download")'
          },
          places_detail: {
            sorting: 2,
            source_type: 'places_detail',
            read_type: 'places',
            endpoint: 'DataCycleCore::Generic::GooglePlaces::Endpoint',
            download_strategy: 'DataCycleCore::Generic::GooglePlaces::DownloadDetail',
            logging_strategy: 'DataCycleCore::Generic::Logger::LogFile.new("download")'
          }
        },
        import: 'DataCycleCore::Generic::BatchImport',
        import_config: {
          tags: {
            sorting: 1,
            source_type: 'places',
            import_strategy: 'DataCycleCore::Generic::GooglePlaces::Keywords',
            data_template: '',
            tree_label: 'GooglePlaces - Tags',
            target_type: 'DataCycleCore::Classification',
            logging_strategy: 'DataCycleCore::Generic::Logger::LogFile.new("import")'
          },
          places: {
            sorting: 2,
            source_type: 'places_detail',
            import_strategy: 'DataCycleCore::Generic::GooglePlaces::Import',
            data_template: 'Örtlichkeit',
            data_type: 'Örtlichkeit',
            target_type: 'DataCycleCore::Place',
            logging_strategy: 'DataCycleCore::Generic::Logger::LogFile.new("import")'
          }
        }
      }
    )
  end

  it 'produces a import_config' do
    subject.import_config.must_equal subject.config['import_config'].symbolize_keys
  end

  it 'returns nil if no import_config is defined' do
    subject.config = nil
    subject.import_config.must_be_nil
    subject.import_list.must_be_nil
  end

  it 'produces a list of available import steps' do
    subject.import_list.must_equal [:tags, :places]
  end

  it 'produces a download_config' do
    subject.download_config.must_equal subject.config['download_config'].symbolize_keys
  end

  it 'produces a list of available download steps' do
    subject.download_list.must_equal [:places, :places_detail]
  end

  it 'throws an exception if import_single can not find its config' do
    proc { subject.import_single(:xxx, { test: 'servas' }) }.must_raise ArgumentError
  end

  it 'throws an exception if import can not find a config' do
    proc { subject.import(:xxx, { test: 'servas' }) }.must_raise ArgumentError
  end

  it 'import_single method should call elementary_importer with appropriate arguments' do
    config_hash = Hash({ import: { places: subject.config.dig('import_config', 'places').symbolize_keys } })
    mock = MiniTest::Mock.new
    mock.expect(:elementary_importer, nil, [config_hash])
    subject.stub(:elementary_importer, ->(arg) { mock.elementary_importer(arg) }) do |object|
      object.import_single(:places)
    end
    mock.verify.must_equal true
  end

  it 'import_single method should call elementary_importer with appropriate arguments and includes supplementary parameters' do
    config_hash = Hash({ arg1: 'test', import: { places: subject.config.dig('import_config', 'places').symbolize_keys } })
    mock = MiniTest::Mock.new
    mock.expect(:elementary_importer, nil, [config_hash])
    subject.stub(:elementary_importer, ->(arg) { mock.elementary_importer(arg) }) do |object|
      object.import_single(:places, { arg1: 'test' })
    end
    mock.verify.must_equal true
  end

  it 'produces a download_config' do
    subject.download_config.must_equal subject.config['download_config'].symbolize_keys
  end

  it 'returns nil if no download_config is defined' do
    subject.config = nil
    subject.download_config.must_be_nil
    subject.download_list.must_be_nil
  end

  it 'throws an exception if download_single can not find its config' do
    proc { subject.download_single(:xxx, { test: 'servas' }) }.must_raise ArgumentError
  end

  it 'throws an exception if download can not find a config' do
    proc { subject.download(:xxx, { test: 'servas' }) }.must_raise ArgumentError
  end

  it 'download_single method should call elementary_downloader with appropriate arguments' do
    config_hash = Hash({ download: { places: subject.config.dig('download_config', 'places').symbolize_keys } })
    mock = MiniTest::Mock.new
    mock.expect(:elementary_downloader, nil, [config_hash])
    subject.stub(:elementary_downloader, ->(arg) { mock.elementary_downloader(arg) }) do |object|
      object.download_single(:places)
    end
    mock.verify.must_equal true
  end

  it 'download_single method should call elementary_downloader with appropriate arguments and includes supplementary parameters' do
    config_hash = Hash({ arg1: 'tst', arg2: 'test', download: { places: subject.config.dig('download_config', 'places').symbolize_keys } })
    mock = MiniTest::Mock.new
    mock.expect(:elementary_downloader, nil, [config_hash])
    subject.stub(:elementary_downloader, ->(arg) { mock.elementary_downloader(arg) }) do |object|
      object.download_single(:places, { arg1: 'tst', arg2: 'test' })
    end
    mock.verify.must_equal true
  end
end
