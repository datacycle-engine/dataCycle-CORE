# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::ExternalSystem do
  include DataCycleCore::MinitestSpecHelper

  subject do
    DataCycleCore::ExternalSystem.new(
      name: 'System Test',
      credentials: {
        host: 'https://test/',
        end_point: 'maps/api/place/',
        key: 'testkey'
      },
      config: {
        export_config: {},
        refresh_config: {},
        download_config: {
          places: {
            sorting: 1,
            source_type: 'places',
            endpoint: 'DataCycleCore::Generic::Places::Endpoint',
            download_strategy: 'DataCycleCore::Generic::Places::Download'
          },
          places_detail: {
            sorting: 2,
            source_type: 'places_detail',
            read_type: 'places',
            endpoint: 'DataCycleCore::Generic::Places::Endpoint',
            download_strategy: 'DataCycleCore::Generic::Places::Download'
          }
        },
        import_config: {
          keywords: {
            sorting: 1,
            source_type: 'places',
            import_strategy: 'DataCycleCore::Generic::Common::ImportTags',
            tree_label: 'Places - Tags',
            tag_id_path: 'types',
            tag_name_path: 'types',
            external_id_prefix: 'Places - Tags - '
          },
          places: {
            sorting: 2,
            source_type: 'places_detail',
            import_strategy: 'DataCycleCore::Generic::Places::Import',
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

  it 'produces a export_config' do
    assert_equal(subject.export_config, subject.config['export_config'].symbolize_keys)
  end

  it 'returns nil if no export_config is defined' do
    subject.config = nil
    subject.reset_memoized_variables!

    assert_nil(subject.export_config)
  end

  it 'produces a refresh_config' do
    assert_equal(subject.refresh_config, subject.config['refresh_config'].symbolize_keys)
  end

  it 'returns nil if no refresh_config is defined' do
    subject.config = nil
    subject.reset_memoized_variables!

    assert_nil(subject.refresh_config)
  end

  it 'produces a import_config' do
    assert_equal(subject.import_config, subject.config['import_config'])
  end

  it 'returns nil if no import_config is defined' do
    subject.config = nil
    subject.reset_memoized_variables!

    assert_nil(subject.import_config)
    assert_nil(subject.import_list)
  end

  it 'produces a list of available import steps' do
    assert_equal([:keywords, :places], subject.import_list)
  end

  it 'produces a download_config' do
    assert_equal(subject.download_config, subject.config['download_config'])
  end

  it 'produces a list of available download steps' do
    assert_equal([:places, :places_detail], subject.download_list)
  end

  it 'throws an exception if import_single can not find its config' do
    assert_raises(RuntimeError) { subject.import_single(:xxx, { test: 'servas' }) }
  end

  it 'throws an exception if import can not find a config' do
    assert_raises(ArgumentError) { subject.import(:xxx, { test: 'servas' }) }
  end

  it 'produces a download_config' do
    assert_equal(subject.download_config, subject.config['download_config'])
  end

  it 'returns nil if no download_config is defined' do
    subject.config = nil
    subject.reset_memoized_variables!

    assert_nil(subject.download_config)
    assert_nil(subject.download_list)
  end

  it 'throws an exception if download_single can not find its config' do
    assert_raises(RuntimeError) { subject.download_single(:xxx, { test: 'servas' }) }
  end

  it 'throws an exception if download can not find a config' do
    assert_raises(ArgumentError) { subject.download(:xxx, { test: 'servas' }) }
  end

  it 'produces a name_with_types string' do
    assert_equal("#{subject.name} [import]", subject.name_with_types)
  end

  it 'is not deactivated (default)' do
    assert_same(false, subject.deactivated)
  end
end
