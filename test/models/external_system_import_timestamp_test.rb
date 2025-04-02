# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'
require 'minitest/autorun'
require 'helpers/minitest_spec_helper'

describe DataCycleCore::ExternalSystem do
  include DataCycleCore::MinitestSpecHelper

  subject do
    @subject ||= DataCycleCore::ExternalSystem.create(
      name: 'System Test',
      credentials: {
        host: 'https://test/',
        end_point: 'maps/api/place/',
        key: 'testkey'
      },
      config: {
        export_config: {
        },
        refresh_config: {
        },
        download_config: {
          places: {
            sorting: 1,
            source_type: 'places',
            endpoint: 'DataCycleCore::Generic::Places::Endpoint',
            download_strategy: 'DataCycleCore::Generic::Common::DownloadBulkMarkDeletedFromEndpoint'
          },
          places_detail: {
            sorting: 2,
            source_type: 'places_detail',
            read_type: 'places',
            endpoint: 'DataCycleCore::Generic::Places::Endpoint',
            download_strategy: 'DataCycleCore::Generic::Common::DownloadBulkMarkDeletedFromEndpoint'
          }
        },
        import_config: {
          keywords: {
            sorting: 1,
            source_type: 'places',
            import_strategy: 'DataCycleCore::Generic::Common::Cleanup',
            tree_label: 'Places - Tags',
            tag_id_path: 'types',
            tag_name_path: 'types',
            external_id_prefix: 'Places - Tags - '
          },
          places: {
            sorting: 2,
            source_type: 'places_detail',
            import_strategy: 'DataCycleCore::Generic::Common::Cleanup',
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

  it 'import step successful' do
    collect_arguments = lambda do |*_args|
      true
    end

    subject.download_config.dig('places', 'download_strategy').constantize.stub :download_content, collect_arguments do
      subject.import_step('places', {}, subject.download_config['places'])
    end

    assert(subject.last_try('places').present?)
    assert(subject.last_try_time('places').present?)
    assert(subject.last_successful_try('places').present?)
    assert(subject.last_successful_try_time('places').present?)
  end

  it 'import step fails' do
    collect_arguments = lambda do |*_args|
      false
    end

    subject.download_config.dig('places', 'download_strategy').constantize.stub :download_content, collect_arguments do
      subject.import_step('places', {}, subject.download_config['places'])
    end

    assert(subject.last_try('places').present?)
    assert(subject.last_try_time('places').present?)
    assert(subject.last_successful_try('places').nil?)
    assert(subject.last_successful_try_time('places').nil?)
  end

  it 'import step error' do
    collect_arguments = lambda do |*_args|
      # forced error to check behaviour of last_try entries if import has an exception
      raise 'forced error'
    end

    assert_raises RuntimeError do
      subject.download_config.dig('places', 'download_strategy').constantize.stub :download_content, collect_arguments do
        subject.import_step('places', {}, subject.download_config['places'])
      end
    end

    assert(subject.last_try('places').present?)
    assert(subject.last_try_time('places').present?)
    assert(subject.last_successful_try('places').nil?)
    assert(subject.last_successful_try_time('places').nil?)
  end

  it 'download successful' do
    collect_arguments = lambda do |*_args|
      true
    end

    subject.download_config.dig('places', 'download_strategy').constantize.stub :download_content, collect_arguments do
      subject.download
    end

    assert(subject.last_try('places').present?)
    assert(subject.last_try_time('places').present?)
    assert(subject.last_successful_try('places').present?)
    assert(subject.last_successful_try_time('places').present?)
  end

  it 'import successful' do
    collect_arguments = lambda do |*_args|
      true
    end

    subject.import_config.dig('keywords', 'import_strategy').constantize.stub :import_data, collect_arguments do
      subject.import
    end

    assert(subject.last_try('keywords').present?)
    assert(subject.last_try_time('keywords').present?)
    assert(subject.last_successful_try('keywords').present?)
    assert(subject.last_successful_try_time('keywords').present?)
  end
end
