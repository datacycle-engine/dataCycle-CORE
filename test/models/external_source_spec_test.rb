# frozen_string_literal: true

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
        download_config: {
          places: {
            sorting: 1,
            source_type: 'places',
            endpoint: 'DataCycleCore::Generic::GooglePlaces::Endpoint',
            download_strategy: 'DataCycleCore::Generic::GooglePlaces::Download'
          },
          places_detail: {
            sorting: 2,
            source_type: 'places_detail',
            read_type: 'places',
            endpoint: 'DataCycleCore::Generic::GooglePlaces::Endpoint',
            download_strategy: 'DataCycleCore::Generic::GooglePlaces::Download'
          }
        },
        import_config: {
          keywords: {
            sorting: 1,
            source_type: 'places',
            import_strategy: 'DataCycleCore::Generic::Common::ImportTags',
            tree_label: 'GooglePlaces - Tags',
            tag_id_path: 'types',
            tag_name_path: 'types',
            external_id_prefix: 'GooglePlaces - Tags - '
          },
          places: {
            sorting: 2,
            source_type: 'places_detail',
            import_strategy: 'DataCycleCore::Generic::GooglePlaces::Import',
            transformations: {
              place: {
                content_type: 'DataCycleCore::Thing',
                template: 'Örtlichkeit'
              }
            }
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
    subject.import_list.must_equal [:keywords, :places]
  end

  it 'produces a download_config' do
    subject.download_config.must_equal subject.config['download_config'].symbolize_keys
  end

  it 'produces a list of available download steps' do
    subject.download_list.must_equal [:places, :places_detail]
  end

  it 'throws an exception if import_single can not find its config' do
    proc { subject.import_single(:xxx, { test: 'servas' }) }.must_raise RuntimeError
  end

  it 'throws an exception if import can not find a config' do
    proc { subject.import(:xxx, { test: 'servas' }) }.must_raise ArgumentError
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
    proc { subject.download_single(:xxx, { test: 'servas' }) }.must_raise RuntimeError
  end

  it 'throws an exception if download can not find a config' do
    proc { subject.download(:xxx, { test: 'servas' }) }.must_raise ArgumentError
  end
end
