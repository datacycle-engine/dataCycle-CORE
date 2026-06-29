# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DcDownloadContentTestEndpoint
    def initialize(**_options)
    end

    def content_items(lang:) # rubocop:disable Lint/UnusedMethodArgument
      [
        { 'id' => 'ep-1', 'name' => 'Endpoint 1' },
        { 'id' => 'ep-2', 'name' => 'Endpoint 2' }
      ]
    end
  end

  class GenericCommonDownloadContentFunctionsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SUBJECT = DataCycleCore::Generic::Common::DownloadFunctions

    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.create!(
        name: 'Download Content Functions Test System',
        identifier: 'download-content-functions-test-system',
        config: {
          'download_config' => {
            'content test' => {
              'source_type' => 'dcf_things',
              'download_strategy' => 'DataCycleCore::Generic::Common::DownloadFunctions'
            }
          }
        }
      )
    end

    after(:all) do
      DataCycleCore::MongoHelper.drop_mongo_db('download-content-functions-test-system')
    end

    def download_object(source_type, locales: [:de])
      DataCycleCore::Generic::DownloadObject.new(
        external_source: @external_source,
        locales:,
        download: {
          source_type:,
          name: 'content test',
          download_strategy: 'DataCycleCore::Generic::Common::DownloadFunctions'
        }
      )
    end

    def seed_item(object, external_id, dump, external_system: nil)
      object.with_mongodb do
        object.source_object.with(object.source_type) do |mongo_item|
          item = mongo_item.find_or_initialize_by(external_id:)
          item.dump = dump
          item.external_system = external_system if external_system
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

    def all_items(object)
      object.with_mongodb do
        object.source_object.with(object.source_type) do |mongo_item|
          mongo_item.all.to_a
        end
      end
    end

    test 'download_content stores items yielded by the iterator' do
      object = download_object('dcf_basic')
      iterator = lambda { |**_kwargs|
        [
          { 'id' => 'cc-1', 'name' => 'CC 1' },
          { 'id' => 'cc-2', 'name' => 'CC 2' },
          { 'id' => 'cc-3' } # no name -> exercises the data_name fallback
        ]
      }

      result = SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      assert result

      item = load_item(object, 'cc-1')

      assert_equal 'CC 1', item.dump.dig('de', 'name')
      assert_equal 'cc-1', item.dump.dig('de', 'dc_external_id')
      assert_equal 'CC 2', load_item(object, 'cc-2').dump.dig('de', 'name')
      assert_predicate load_item(object, 'cc-3'), :present?
    end

    test 'download_content with config props merges them into the stored data' do
      object = download_object('dcf_props')
      iterator = ->(**_kwargs) { [{ 'id' => 'pr-1', 'name' => 'Prop 1' }] }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: { tree_label: 'Tags', external_id_prefix: 'pre_' } }
      )

      item = load_item(object, 'pr-1')

      assert_equal 'Tags', item.dump.dig('de', 'tree_label')
      assert_equal 'pre_', item.dump.dig('de', 'external_id_prefix')
    end

    test 'download_content respects max_count' do
      object = download_object('dcf_max')
      iterator = lambda { |**_kwargs|
        [{ 'id' => 'mc-1', 'name' => 'MC 1' }, { 'id' => 'mc-2', 'name' => 'MC 2' }]
      }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], max_count: 1, download: {} }
      )

      assert_predicate load_item(object, 'mc-1'), :present?
      assert_nil load_item(object, 'mc-2')
    end

    test 'download_content flushes full slices and skips blank items' do
      object = download_object('dcf_slices')
      batch = (1..DataCycleCore::Generic::Common::Extensions::DownloadContentFunctions::DELTA).map do |i|
        { 'id' => "sl-#{i}", 'name' => "Slice #{i}" }
      end
      batch << nil # exercises the blank-item guard
      batch << { 'id' => 'sl-last', 'name' => 'Slice last' }
      iterator = ->(**_kwargs) { batch }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      assert_predicate load_item(object, 'sl-1'), :present?
      assert_predicate load_item(object, 'sl-100'), :present?
      assert_predicate load_item(object, 'sl-last'), :present?
    end

    test 'download_content_all stores locale keyed data for every locale' do
      object = download_object('dcf_all', locales: [:de, :en])
      iterator = lambda { |**_kwargs|
        [{ 'de' => { 'id' => 'ac-1', 'name' => 'DE name' }, 'en' => { 'id' => 'ac-1', 'name' => 'EN name' } }]
      }

      SUBJECT.download_content_all(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de, :en], download: {} }
      )

      item = load_item(object, 'ac-1')

      assert_equal 'DE name', item.dump.dig('de', 'name')
      assert_equal 'EN name', item.dump.dig('en', 'name')
    end

    test 'download_content loads items from the configured endpoint when no iterator is given' do
      object = download_object('dcf_endpoint')

      SUBJECT.download_content(
        download_object: object,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: {
          locales: [:de],
          download: {
            endpoint: 'DataCycleCore::DcDownloadContentTestEndpoint',
            endpoint_method: 'content_items'
          }
        }
      )

      assert_equal 'Endpoint 1', load_item(object, 'ep-1').dump.dig('de', 'name')
      assert_equal 'Endpoint 2', load_item(object, 'ep-2').dump.dig('de', 'name')
    end

    test 'download_content adds the credential key from the credentials hash' do
      object = download_object('dcf_cred')
      iterator = ->(**_kwargs) { [{ 'id' => 'cr-1', 'name' => 'Cred 1' }] }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {}, credentials: { 'credential_key' => 'my-cred' } }
      )

      assert_includes load_item(object, 'cr-1').external_system['credential_keys'], 'my-cred'
    end

    test 'download_content extracts credential keys embedded in the item data' do
      object = download_object('dcf_data_cred')
      iterator = lambda { |**_kwargs|
        [{ 'id' => 'dc-1', 'name' => 'DC 1', external_system: { credential_keys: ['data-cred'] } }]
      }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      item = load_item(object, 'dc-1')

      assert_includes item.external_system['credential_keys'], 'data-cred'
      assert_nil item.dump.dig('de', 'external_system')
    end

    test 'download_content touches unchanged items instead of rewriting them' do
      object = download_object('dcf_touch')
      seed_item(object, 'tc-1', { 'de' => { 'id' => 'tc-1', 'name' => 'Touch 1', 'dc_external_id' => 'tc-1' } })
      iterator = ->(**_kwargs) { [{ 'id' => 'tc-1', 'name' => 'Touch 1' }] }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      item = load_item(object, 'tc-1')

      assert_equal 'Touch 1', item.dump.dig('de', 'name')
      assert_predicate item.seen_at, :present?
    end

    test 'download_content handles an empty result set' do
      object = download_object('dcf_empty')

      result = SUBJECT.download_content(
        download_object: object,
        iterator: ->(**_kwargs) { [] },
        data_id: ->(data) { data['id'] },
        options: { locales: [:de], download: {} }
      )

      assert result
      assert_empty all_items(object)
    end

    test 'incremental download_content filters by the last successful try' do
      object = download_object('dcf_incremental')
      captured = nil
      iterator = lambda { |source_filter:, **_kwargs|
        captured = source_filter
        []
      }

      object.stub(:last_successful_try, Time.zone.local(2020, 1, 1)) do
        SUBJECT.download_content(
          download_object: object,
          iterator:,
          data_id: ->(data) { data['id'] },
          options: { locales: [:de], download: {} }
        )
      end

      assert_predicate captured[:updated_at], :present?
    end

    test 'download_content iterates each locale separately' do
      object = download_object('dcf_iter_locales', locales: [:de, :en])
      locales_seen = []
      iterator = lambda { |locale:, **_kwargs|
        locales_seen << locale
        [{ 'id' => "il-#{locale}", 'name' => "Name #{locale}" }]
      }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de, :en], download: {} }
      )

      assert_equal [:de, :en], locales_seen.sort
      assert_equal 'Name de', load_item(object, 'il-de').dump.dig('de', 'name')
      assert_equal 'Name en', load_item(object, 'il-en').dump.dig('en', 'name')
    end

    test 'download_content iterates over an array of credentials' do
      object = download_object('dcf_iter_creds')
      iterator = ->(**_kwargs) { [{ 'id' => 'icr-1', 'name' => 'Cred item' }] }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {}, credentials: [{ 'credential_key' => 'k1' }, { 'credential_key' => 'k2' }] }
      )

      keys = load_item(object, 'icr-1').external_system['credential_keys']

      assert_includes keys, 'k1'
      assert_includes keys, 'k2'
    end

    test 'download_content iterates over an array of read types' do
      object = download_object('dcf_iter_rt')
      read_types_seen = []
      iterator = lambda { |options:, **_kwargs|
        read_types_seen << options.dig(:download, :read_type)
        [{ 'id' => 'rt-1', 'name' => 'RT' }]
      }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: { read_type: ['type_a', 'type_b'] } }
      )

      assert_equal ['type_a', 'type_b'], read_types_seen.sort
      assert_predicate load_item(object, 'rt-1'), :present?
    end

    test 'download_content raises when the deprecated delete kwarg is given' do
      object = download_object('dcf_delete_raise')

      assert_raises(DataCycleCore::Generic::Common::Error::ImporterError) do
        SUBJECT.download_content(
          download_object: object,
          iterator: ->(**_kwargs) { [] },
          delete: ->(_data) { true },
          options: { locales: [:de], download: {} }
        )
      end
    end

    test 'bulk_touch_items clears deletion markers and updates seen_at' do
      object = download_object('dcf_touch_bulk')
      seed_item(object, 'bt-1', {
        'de' => {
          'id' => 'bt-1',
          'deleted_at' => Time.zone.now,
          'last_seen_before_delete' => Time.zone.now,
          'delete_reason' => 'gone'
        }
      })
      iterator = ->(**_kwargs) { ['bt-1'] }

      SUBJECT.bulk_touch_items(
        download_object: object,
        iterator:,
        options: { locales: [:de], download: {} }
      )

      item = load_item(object, 'bt-1')

      assert_nil item.dump.dig('de', 'deleted_at')
      assert_nil item.dump.dig('de', 'last_seen_before_delete')
      assert_nil item.dump.dig('de', 'delete_reason')
      assert_predicate item.seen_at, :present?
    end

    test 'bulk_mark_deleted flags items as deleted' do
      object = download_object('dcf_mark_bulk')
      seed_item(object, 'bm-1', { 'de' => { 'id' => 'bm-1', 'name' => 'Mark me' } })
      iterator = ->(**_kwargs) { ['bm-1'] }

      SUBJECT.bulk_mark_deleted(
        download_object: object,
        iterator:,
        options: { locales: [:de], download: { delete_reason: 'no longer at source' } }
      )

      item = load_item(object, 'bm-1')

      assert_predicate item.dump.dig('de', 'deleted_at'), :present?
      assert_predicate item.dump.dig('de', 'last_seen_before_delete'), :present?
      assert_equal 'no longer at source', item.dump.dig('de', 'delete_reason')
    end

    test 'bulk_mark_deleted returns early when no keys are found' do
      object = download_object('dcf_mark_empty')

      result = SUBJECT.bulk_mark_deleted(
        download_object: object,
        iterator: ->(**_kwargs) { [] },
        options: { locales: [:de], download: {} }
      )

      assert result
      assert_empty all_items(object)
    end

    test 'item_allowed? compares step priority against item priority' do
      assert SUBJECT.send(:item_allowed?, local_item: nil, options: {})
      assert SUBJECT.send(:item_allowed?, local_item: { priority: 3 }, options: { download: {} })
      assert SUBJECT.send(:item_allowed?, local_item: { priority: 9 }, options: { download: { priority: 5 } })
      assert_not SUBJECT.send(:item_allowed?, local_item: { priority: 3 }, options: { download: { priority: 5 } })
    end
  end
end
