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

    # one item exercising the delete-marker, embedded-credential, included-data and
    # unknown-key branches of download_all in a single pass
    def rich_items(*_args)
      [
        {
          'de' => { external_system: { credential_keys: ['ck-1'] }, 'id' => 'da-rich', 'name' => 'Rich' },
          'included' => [{ 'inc' => 1 }],
          'en' => { 'id' => 'da-rich-en' }
        }
      ]
    end

    # exactly DELTA (100) items to cross the progress/GC batch boundary in download_all
    def hundred_items(*_args)
      (1..100).map { |i| { 'de' => { 'id' => "batch-#{i}", 'name' => "Item #{i}" } } }
    end

    def ghost_deleted_ids(lang:, deleted_from:) # rubocop:disable Lint/UnusedMethodArgument
      ['ghost-404']
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

    test 'download_single strips stale delete markers when the delete filter no longer matches' do
      object = download_object('dft_single_keep')
      raw_data = { 'de' => { 'id' => 'single-3', 'name' => 'Kept', 'deleted_at' => 'stale', 'delete_reason' => 'stale' } }

      SUBJECT.download_single(
        download_object: object,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        delete: ->(_data, _language) { false },
        raw_data:,
        options: { locales: [:de], download: {} }
      )

      item = load_item(object, 'single-3')

      assert_nil item.dump.dig('de', 'deleted_at')
      assert_nil item.dump.dig('de', 'delete_reason')
    end

    test 'download_all applies delete markers, embedded credentials, included data and skips unknown keys' do
      object = download_object('dft_all_rich')
      seed_item(object, 'da-rich', {
        'de' => {
          'deleted_at' => 1.day.ago,
          'delete_reason' => 'previously removed',
          'last_seen_before_delete' => 2.days.ago,
          'archived_at' => 3.days.ago,
          'archive_reason' => 'previously archived',
          'last_seen_before_archived' => 4.days.ago
        }
      })
      options = {
        locales: [:de],
        download: {
          endpoint: 'DataCycleCore::DcDownloadFunctionsTestEndpoint',
          endpoint_method: 'rich_items'
        }
      }

      SUBJECT.download_all(
        download_object: object,
        data_id: ->(data) { data['id'] },
        delete: ->(_data, _key) { true },
        options:
      )

      item = load_item(object, 'da-rich')

      assert_equal 'previously removed', item.dump.dig('de', 'delete_reason')
      assert_predicate item.dump.dig('de', 'last_seen_before_delete'), :present?
      assert_equal 'previously archived', item.dump.dig('de', 'archive_reason')
      assert item.dump.key?('included')
      assert_not item.dump.key?('en')
    end

    test 'download_all emits progress and triggers GC at the DELTA batch boundary' do
      object = download_object('dft_all_batch')
      options = {
        locales: [:de],
        download: {
          endpoint: 'DataCycleCore::DcDownloadFunctionsTestEndpoint',
          endpoint_method: 'hundred_items'
        }
      }

      result = SUBJECT.download_all(download_object: object, data_id: ->(data) { data['id'] }, options:)

      assert result
      assert_predicate load_item(object, 'batch-100'), :present? # last item stored -> loop crossed the batch boundary
    end

    test 'mark_deleted skips endpoint ids that are absent from the collection' do
      object = download_object('dft_mark_deleted_ghost')
      options = {
        locales: ['de'],
        download: {
          endpoint: 'DataCycleCore::DcDownloadFunctionsTestEndpoint',
          endpoint_method: 'ghost_deleted_ids'
        }
      }

      result = SUBJECT.mark_deleted(download_object: object, data_id: ->(data) { data }, options:)

      assert result
      assert_nil load_item(object, 'ghost-404') # absent id raised DocumentNotFound and was skipped, not created
    end

    test 'mark_deleted_from_data archives matching items via the aggregate iterator' do
      object = download_object('dft_mdfd_archive')
      seed_item(object, 'mdfd-arch-1', { 'de' => { 'id' => 'mdfd-arch-1', 'name' => 'Archive me' } })
      options = {
        locales: ['de'],
        iterator_type: :aggregate,
        download: {
          source_filter: { 'dump.de.id' => { '$exists' => true } },
          archive_from: '1.day.from_now',
          archive_reason: 'no longer current'
        }
      }

      SUBJECT.mark_deleted_from_data(
        download_object: object,
        iterator: ->(mongo_item, _locale, source_filter) { mongo_item.where(source_filter) },
        archived: ->(_dump, _archive_from) { true },
        options:
      )

      item = load_item(object, 'mdfd-arch-1')

      assert_predicate item.dump.dig('de', 'archived_at'), :present?
      assert_predicate item.dump.dig('de', 'last_seen_before_archived'), :present?
      assert_equal 'no longer current', item.dump.dig('de', 'archive_reason')
    end

    test 'mark_updated flags affected items via the aggregate iterator' do
      object = download_object('dft_mark_updated_agg')
      seed_item(object, 'upd-agg-1', { 'de' => { 'id' => 'upd-agg-1', 'deps' => ['dep-1'] } })
      options = {
        locales: [:de],
        iterator_type: :aggregate,
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

      assert_predicate load_item(object, 'upd-agg-1').dump.dig('de', 'mark_for_update'), :present?
    end
  end
end
