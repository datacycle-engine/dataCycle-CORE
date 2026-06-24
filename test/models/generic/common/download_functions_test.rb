# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DcDownloadFunctionsTestEndpoint
    def initialize(**_options)
    end

    def downloaded_items(*_args)
      [
        { 'de' => { 'id' => 'all-1', 'name' => 'Item 1' } },
        { 'de' => { 'id' => 'all-2', 'name' => 'Item 2' } }
      ]
    end

    def deleted_ids(lang:, deleted_from:) # rubocop:disable Lint/UnusedMethodArgument
      ['del-1']
    end

    def affected_keys(lang:, deleted_from:) # rubocop:disable Lint/UnusedMethodArgument
      ['dep-1']
    end
  end

  class GenericCommonDownloadFunctionsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SUBJECT = DataCycleCore::Generic::Common::DownloadFunctions

    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.create!(
        name: 'Download Functions Test System',
        identifier: 'download-functions-test-system',
        config: {
          'download_config' => {
            'functions test' => {
              'source_type' => 'dft_things',
              'download_strategy' => 'DataCycleCore::Generic::Common::DownloadFunctions'
            }
          }
        }
      )
    end

    after(:all) do
      DataCycleCore::MongoHelper.drop_mongo_db('download-functions-test-system')
    end

    def download_object(source_type)
      DataCycleCore::Generic::DownloadObject.new(
        external_source: @external_source,
        locales: [:de],
        download: {
          source_type:,
          name: 'functions test',
          download_strategy: 'DataCycleCore::Generic::Common::DownloadFunctions'
        }
      )
    end

    def seed_item(object, external_id, dump)
      object.with_mongodb do
        object.source_object.with(object.source_type) do |mongo_item|
          item = mongo_item.find_or_initialize_by(external_id:)
          item.dump = dump
          item.save!
        end
      end
    end

    def load_item(object, external_id)
      object.with_mongodb do
        object.source_object.with(object.source_type) do |mongo_item|
          mongo_item.where(external_id:).first
        end
      end
    end

    test 'download_single stores raw_data in mongo collection' do
      object = download_object('dft_single')
      raw_data = { 'de' => { 'id' => 'single-1', 'name' => 'Single Item' } }

      result = SUBJECT.download_single(
        download_object: object,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        raw_data:,
        options: { locales: [:de], download: {} }
      )

      assert result

      item = load_item(object, 'single-1')

      assert_equal 'Single Item', item.dump.dig('de', 'name')
      assert_predicate item.seen_at, :present?
    end

    test 'download_single marks filtered data as deleted' do
      object = download_object('dft_single_delete')
      raw_data = { 'de' => { 'id' => 'single-2', 'name' => 'Deleted Item' } }

      SUBJECT.download_single(
        download_object: object,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        delete: ->(_data, _language) { true },
        raw_data:,
        options: { locales: [:de], download: {} }
      )

      item = load_item(object, 'single-2')

      assert_predicate item.dump.dig('de', 'deleted_at'), :present?
      assert_predicate item.dump.dig('de', 'delete_reason'), :present?
    end

    test 'download_all downloads all items from endpoint into mongo' do
      object = download_object('dft_all')
      options = {
        locales: [:de],
        download: {
          endpoint: 'DataCycleCore::DcDownloadFunctionsTestEndpoint',
          endpoint_method: 'downloaded_items'
        }
      }

      result = SUBJECT.download_all(download_object: object, data_id: ->(data) { data['id'] }, options:)

      assert result
      assert_equal 'Item 1', load_item(object, 'all-1').dump.dig('de', 'name')
      assert_equal 'Item 2', load_item(object, 'all-2').dump.dig('de', 'name')
    end

    test 'download_all respects max_count' do
      object = download_object('dft_all_max')
      options = {
        locales: [:de],
        max_count: 1,
        download: {
          endpoint: 'DataCycleCore::DcDownloadFunctionsTestEndpoint',
          endpoint_method: 'downloaded_items'
        }
      }

      SUBJECT.download_all(download_object: object, data_id: ->(data) { data['id'] }, options:)

      assert_predicate load_item(object, 'all-1'), :present?
      assert_nil load_item(object, 'all-2')
    end

    test 'dump_test_data stores raw_data as dump' do
      object = download_object('dft_dump_test')
      raw_data = { 'de' => { 'id' => 'dump-1', 'name' => 'Dump Item' } }

      result = SUBJECT.dump_test_data(
        download_object: object,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        raw_data:,
        options: { locales: [:de] }
      )

      assert result
      assert_equal raw_data, load_item(object, 'dump-1').dump
    end

    test 'dump_raw_data stores raw_data under the configured locale' do
      object = download_object('dft_dump_raw')
      raw_data = { 'id' => 'raw-1', 'name' => 'Raw Item' }

      result = SUBJECT.dump_raw_data(
        download_object: object,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        raw_data:,
        options: { locales: [:de], download: { locales: [:de] } }
      )

      assert result
      assert_equal({ 'de' => raw_data }, load_item(object, 'raw-1').dump)
    end

    test 'mark_deleted flags items returned by the endpoint as deleted' do
      object = download_object('dft_mark_deleted')
      seed_item(object, 'del-1', { 'de' => { 'id' => 'del-1', 'name' => 'To delete' } })
      seed_item(object, 'del-2', { 'de' => { 'id' => 'del-2', 'name' => 'To keep' } })
      options = {
        locales: ['de'],
        download: {
          endpoint: 'DataCycleCore::DcDownloadFunctionsTestEndpoint',
          endpoint_method: 'deleted_ids',
          delete_reason: 'removed at source'
        }
      }

      SUBJECT.mark_deleted(download_object: object, data_id: ->(data) { data }, options:)

      deleted = load_item(object, 'del-1')

      assert_predicate deleted.dump.dig('de', 'deleted_at'), :present?
      assert_predicate deleted.dump.dig('de', 'last_seen_before_delete'), :present?
      assert_equal 'removed at source', deleted.dump.dig('de', 'delete_reason')
      assert_nil load_item(object, 'del-2').dump.dig('de', 'deleted_at')
    end

    test 'mark_deleted_from_data raises without source_filter' do
      object = download_object('dft_mdfd_raise')

      assert_raises(RuntimeError) do
        SUBJECT.mark_deleted_from_data(
          download_object: object,
          iterator: ->(mongo_item, _locale, source_filter) { mongo_item.where(source_filter) },
          options: { locales: ['de'], download: {} }
        )
      end
    end

    test 'mark_deleted_from_data flags all matching items as deleted' do
      object = download_object('dft_mdfd')
      seed_item(object, 'mdfd-1', { 'de' => { 'id' => 'mdfd-1', 'name' => 'Vanished' } })
      options = {
        locales: ['de'],
        download: {
          source_filter: { 'dump.de.id' => { '$exists' => true } },
          delete_reason: 'not seen anymore'
        }
      }

      SUBJECT.mark_deleted_from_data(
        download_object: object,
        iterator: ->(mongo_item, _locale, source_filter) { mongo_item.where(source_filter) },
        options:
      )

      item = load_item(object, 'mdfd-1')

      assert_predicate item.dump.dig('de', 'deleted_at'), :present?
      assert_predicate item.dump.dig('de', 'last_seen_before_delete'), :present?
      assert_equal 'not seen anymore', item.dump.dig('de', 'delete_reason')
    end

    test 'mark_updated flags items depending on affected keys' do
      object = download_object('dft_mark_updated')
      seed_item(object, 'upd-1', { 'de' => { 'id' => 'upd-1', 'deps' => ['dep-1', 'other'] } })
      seed_item(object, 'upd-2', { 'de' => { 'id' => 'upd-2', 'deps' => ['unrelated'] } })
      options = {
        locales: [:de],
        download: {
          endpoint: 'DataCycleCore::DcDownloadFunctionsTestEndpoint',
          endpoint_method: 'affected_keys'
        }
      }

      SUBJECT.mark_updated(
        download_object: object,
        iterator: ->(mongo_item, _locales, source_filter) { mongo_item.where(source_filter) },
        dependent_keys: ->(data) { data['deps'] },
        options:
      )

      assert_predicate load_item(object, 'upd-1').dump.dig('de', 'mark_for_update'), :present?
      assert_nil load_item(object, 'upd-2').dump.dig('de', 'mark_for_update')
    end
  end
end
