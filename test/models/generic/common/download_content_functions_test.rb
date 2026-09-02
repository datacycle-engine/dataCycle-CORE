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

    def stamp_item(object, external_id, **props)
      object.with_mongodb do
        object.source_object.with(object.source_type) do |mongo_item|
          mongo_item.where(external_id:).update_all('$set' => props.stringify_keys)
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

    # Both change-detection tests below stamp a known past `updated_at` first, because a seeded item
    # has none: `Collection#set_updated_at` only calls `super` when `data_has_changed` is set, and
    # `seed_item` never sets it.
    STAMPED_AT = Time.zone.local(2020, 1, 1)

    def download_and_reload(object, external_id, iterator:)
      stamp_item(object, external_id, updated_at: STAMPED_AT, seen_at: STAMPED_AT)

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      load_item(object, external_id)
    end

    # The two tests below pin the change detection of `download_item_slice`, which compares the stored
    # dump against the freshly built payload via `local_item.as_json.eql?(item_data.as_json)` —
    # `local_item` being what Mongoid demongoized out of the `dump` hash field. `updated_at` is the
    # observable: it moves only when the comparison found a difference and `data_has_changed` made
    # `Collection#set_updated_at` call `super`. Asserting only the stored value would pass either way,
    # and both failure directions are silent and expensive — a comparison that stops matching equal
    # payloads rewrites every item on every download, one that stops seeing real differences never
    # lets a change reach the dump.
    test 'download_content touches unchanged items instead of rewriting them' do
      object = download_object('dcf_touch')
      seed_item(object, 'tc-1', { 'de' => { 'id' => 'tc-1', 'name' => 'Touch 1', 'dc_external_id' => 'tc-1' } })

      item = download_and_reload(object, 'tc-1', iterator: ->(**_kwargs) { [{ 'id' => 'tc-1', 'name' => 'Touch 1' }] })

      assert_equal 'Touch 1', item.dump.dig('de', 'name')
      assert_equal STAMPED_AT.to_i, item.updated_at.to_i
      assert_operator item.seen_at, :>, STAMPED_AT
    end

    test 'download_content rewrites an item whose source data changed' do
      object = download_object('dcf_touch_changed')
      seed_item(object, 'tcc-1', { 'de' => { 'id' => 'tcc-1', 'name' => 'Touch 1', 'dc_external_id' => 'tcc-1' } })

      item = download_and_reload(object, 'tcc-1', iterator: ->(**_kwargs) { [{ 'id' => 'tcc-1', 'name' => 'Touch 2' }] })

      assert_equal 'Touch 2', item.dump.dig('de', 'name')
      assert_operator item.updated_at, :>, STAMPED_AT
    end

    # [#51228] A single item mongo refuses to store (#51161: a Feratel document past the 16 MB BSON
    # limit) used to raise out of item.save!, through with_logging's rescue, and abort the whole step.
    # An oversized payload is built rather than stubbed: MaxBSONSize comes out of the driver's own
    # serialization, so only a really oversized document proves the rescue catches what mongo raises.

    test 'download_content keeps the stored dump and touches an item whose rewrite exceeds the BSON limit' do
      object = download_object('dcf_oversized')
      seed_item(object, 'os-1', { 'de' => { 'id' => 'os-1', 'name' => 'Small', 'dc_external_id' => 'os-1' } })
      stamp_item(object, 'os-1', seen_at: 5.days.ago)
      iterator = ->(**_kwargs) { [{ 'id' => 'os-1', 'name' => 'x' * 17.megabytes }] }

      result = SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      assert result

      item = load_item(object, 'os-1')

      assert_equal 'Small', item.dump.dig('de', 'name') # the write was refused, the old dump survives
      # the source still lists it, so it must not age out into the mark_deleted/archive steps
      assert_operator item.seen_at.to_i, :>, 1.hour.ago.to_i
    end

    test 'download_content skips a new item that exceeds the BSON limit instead of failing the step' do
      object = download_object('dcf_oversized_new')
      iterator = ->(**_kwargs) { [{ 'id' => 'os-new-1', 'name' => 'x' * 17.megabytes }] }

      result = SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      assert result
      assert_nil load_item(object, 'os-new-1') # nothing was ever persisted, so there is nothing to touch
    end

    test 'download_content stores the rest of the slice after an item exceeds the BSON limit' do
      object = download_object('dcf_oversized_continue')
      iterator = lambda { |**_kwargs|
        [
          { 'id' => 'os-bad', 'name' => 'x' * 17.megabytes },
          { 'id' => 'os-good', 'name' => 'Good item' }
        ]
      }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      assert_equal 'Good item', load_item(object, 'os-good').dump.dig('de', 'name')
    end

    test 'download_content instruments the failing item with its exception and external_id' do
      object = download_object('dcf_oversized_notify')
      iterator = ->(**_kwargs) { [{ 'id' => 'os-notify', 'name' => 'x' * 17.megabytes }] }
      captured = []
      step_failures = []

      ActiveSupport::Notifications.subscribed(->(_n, _s, _f, _u, data) { step_failures << data }, /(download|dump|mark_deleted)_failed.datacycle/) do
        ActiveSupport::Notifications.subscribed(
          ->(_name, _started, _finished, _unique_id, data) { captured << data },
          'download_item_failed.datacycle'
        ) do
          SUBJECT.download_content(
            download_object: object,
            iterator:,
            data_id: ->(data) { data['id'] },
            data_name: ->(data) { data['name'] },
            options: { locales: [:de], download: {} }
          )
        end
      end

      assert_equal 1, captured.size
      assert_instance_of Mongo::Error::MaxBSONSize, captured.first[:exception]
      assert_equal 'os-notify', captured.first[:item_id]
      assert_equal @external_source, captured.first[:external_system]
      # without an explicit message, InstrumentationLogger#dc_log falls back to rendering every error
      # payload as "<step_label> ... [FAILED]" -- announcing the step as aborted when it kept running
      assert_match(/item os-notify not stored/, captured.first[:message])
      # the whole point of the separate channel: a single unwritable item must not reach
      # check_for_repeated_failure, which would mail this out as a repeatedly failing download
      assert_empty step_failures
    end

    # MaxMessageSize shares the rescue with MaxBSONSize, but the driver raises it for a whole message
    # rather than a single document, so no payload provokes it from here -- hence the only stub in
    # this group. mongo_item.new is the seam: an existing item is instantiated straight from the
    # criteria, a new one is not.
    test 'download_content keeps the step running when an item exceeds the max message size' do
      object = download_object('dcf_max_message')
      build_item = DataCycleCore::Generic::Collection.method(:new) # bound before the stub, or it calls itself
      raise_on_save = lambda { |*args, **kwargs, &blk|
        build_item.call(*args, **kwargs, &blk).tap do |record|
          record.define_singleton_method(:save!) { |*| raise Mongo::Error::MaxMessageSize } if kwargs[:external_id] == 'os-msg'
        end
      }
      iterator = lambda { |**_kwargs|
        [
          { 'id' => 'os-msg', 'name' => 'Unwritable' },
          { 'id' => 'os-msg-good', 'name' => 'Good item' }
        ]
      }
      captured = []

      ActiveSupport::Notifications.subscribed(->(_name, _started, _finished, _unique_id, data) { captured << data }, 'download_item_failed.datacycle') do
        DataCycleCore::Generic::Collection.stub(:new, raise_on_save) do
          result = SUBJECT.download_content(
            download_object: object,
            iterator:,
            data_id: ->(data) { data['id'] },
            data_name: ->(data) { data['name'] },
            options: { locales: [:de], download: {} }
          )

          assert result
        end
      end

      assert_nil load_item(object, 'os-msg')
      assert_equal 'Good item', load_item(object, 'os-msg-good').dump.dig('de', 'name')
      assert_equal 1, captured.size
      assert_instance_of Mongo::Error::MaxMessageSize, captured.first[:exception]
      assert_equal 'os-msg', captured.first[:item_id]
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

    test 'bulk_touch_items bumps updated_at of revived items so an incremental import picks them up' do
      object = download_object('dcf_touch_revive')
      seed_item(object, 'br-1', { 'de' => { 'id' => 'br-1', 'deleted_at' => Time.zone.now, 'delete_reason' => 'gone' } })
      stamp_item(object, 'br-1', updated_at: 2.days.ago)

      SUBJECT.bulk_touch_items(
        download_object: object,
        iterator: ->(**_kwargs) { ['br-1'] },
        options: { locales: [:de], download: {} }
      )

      item = load_item(object, 'br-1')

      assert_nil item.dump.dig('de', 'deleted_at')
      assert_operator item.updated_at.to_i, :>, 1.hour.ago.to_i
    end

    test 'bulk_touch_items keeps updated_at of items that were not flagged deleted' do
      object = download_object('dcf_touch_keep')
      seed_item(object, 'bk-1', { 'de' => { 'id' => 'bk-1' } })
      updated_at = 2.days.ago
      stamp_item(object, 'bk-1', updated_at:)

      SUBJECT.bulk_touch_items(
        download_object: object,
        iterator: ->(**_kwargs) { ['bk-1'] },
        options: { locales: [:de], download: {} }
      )

      item = load_item(object, 'bk-1')

      # bumping updated_at for every touched item would re-import the whole dataset on every incremental run
      assert_equal updated_at.to_i, item.updated_at.to_i
      assert_operator item.seen_at.to_i, :>, 1.hour.ago.to_i
    end

    test 'bulk_touch_items touches items that have no dump for the touched locale' do
      object = download_object('dcf_touch_other_locale')
      seed_item(object, 'bo-1', { 'en' => { 'id' => 'bo-1' } })
      stamp_item(object, 'bo-1', seen_at: 5.days.ago)

      SUBJECT.bulk_touch_items(
        download_object: object,
        iterator: ->(**_kwargs) { ['bo-1'] },
        options: { locales: [:de], download: {} }
      )

      # seen_at is document level: a document that has no de dump must not go stale and get deleted
      # in the languages it does have
      assert_operator load_item(object, 'bo-1').seen_at.to_i, :>, 1.hour.ago.to_i
    end

    test 'bulk_touch_items only revives the touched locale' do
      object = download_object('dcf_touch_locale_scope')
      deleted = { 'deleted_at' => Time.zone.now, 'last_seen_before_delete' => Time.zone.now, 'delete_reason' => 'gone' }
      seed_item(object, 'bl-1', { 'de' => { 'id' => 'bl-1' }.merge(deleted), 'en' => { 'id' => 'bl-1' }.merge(deleted) })

      SUBJECT.bulk_touch_items(
        download_object: object,
        iterator: ->(**_kwargs) { ['bl-1'] },
        options: { locales: [:de], download: {} }
      )

      item = load_item(object, 'bl-1')

      assert_nil item.dump.dig('de', 'deleted_at')
      # the touch is not scoped to documents carrying a de dump anymore, so the delete markers of every
      # other language have to survive it
      assert_predicate item.dump.dig('en', 'deleted_at'), :present?
      assert_equal 'gone', item.dump.dig('en', 'delete_reason')
    end

    test 'bulk_touch_items raises when no external key can be derived from the source payloads' do
      object = download_object('dcf_touch_no_key')

      error = assert_raises(DataCycleCore::Generic::Common::Error::ImporterError) do
        SUBJECT.bulk_touch_items(
          download_object: object,
          iterator: ->(**_kwargs) { [{ 'id' => 'nk-1' }, { 'id' => 'nk-2' }] },
          options: { locales: [:de], download: {} }
        )
      end

      # a step that resolves no key touches nothing, and everything it should have touched then ages
      # out into the "not seen in x days" delete steps -- that has to fail loudly
      assert_match(/external_key_path/, error.message)
    end

    test 'bulk_touch_items skips single payloads without a key instead of failing the step' do
      object = download_object('dcf_touch_partial_key')
      seed_item(object, 'pk-1', { 'de' => { 'id' => 'pk-1' } })
      stamp_item(object, 'pk-1', seen_at: 5.days.ago)

      SUBJECT.bulk_touch_items(
        download_object: object,
        iterator: ->(**_kwargs) { [{ 'id' => 'pk-1' }, { 'name' => 'no id at all' }] },
        data_id: ->(data) { data['id'] },
        options: { locales: [:de], download: {} }
      )

      assert_operator load_item(object, 'pk-1').seen_at.to_i, :>, 1.hour.ago.to_i
    end

    test 'bulk_mark_deleted flags items as deleted' do
      object = download_object('dcf_mark_bulk')
      seed_item(object, 'bm-1', { 'de' => { 'id' => 'bm-1', 'name' => 'Mark me' } })
      iterator = ->(**_kwargs) { ['bm-1'] }
      seen_at = load_item(object, 'bm-1').seen_at

      SUBJECT.bulk_mark_deleted(
        download_object: object,
        iterator:,
        options: { locales: [:de], download: { delete_reason: 'no longer at source' } }
      )

      item = load_item(object, 'bm-1')

      assert_predicate item.dump.dig('de', 'deleted_at'), :present?
      # the last time the source still listed the item, copied from the document's own seen_at
      assert_equal seen_at.to_i, item.dump.dig('de', 'last_seen_before_delete').to_i
      assert_equal 'no longer at source', item.dump.dig('de', 'delete_reason')
    end

    test 'bulk_mark_deleted stores a delete_reason starting with $ as a value' do
      object = download_object('dcf_mark_literal')
      seed_item(object, 'bm-2', { 'de' => { 'id' => 'bm-2' } })

      SUBJECT.bulk_mark_deleted(
        download_object: object,
        iterator: ->(**_kwargs) { ['bm-2'] },
        options: { locales: [:de], download: { delete_reason: '$seen_at' } }
      )

      # without the $literal wrapper the aggregation pipeline reads this as a field path and stores the
      # document's own seen_at instead of the configured reason
      assert_equal '$seen_at', load_item(object, 'bm-2').dump.dig('de', 'delete_reason')
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

    # [#50666] Keys DataCycle owns inside dump.<locale> are stripped from the source payload before it
    # becomes the dump, so nothing a source ships can be read back as one of ours.

    test 'download_content strips DataCycle owned keys from the source payload' do
      object = download_object('dcf_strip')
      iterator = lambda { |**_kwargs|
        [{
          'id' => 'st-1',
          'name' => 'Strip 1',
          'deleted_at' => 1.day.ago,
          'delete_reason' => 'source says so',
          'last_seen_before_delete' => 2.days.ago,
          'archived_at' => 3.days.ago,
          'archive_reason' => 'source says so',
          'last_seen_before_archived' => 4.days.ago,
          'mark_for_update' => 5.days.ago,
          'dc_external_id' => 'not-ours',
          'dc_step_priority' => 0, # not even ours is trusted from the payload
          'priority' => 0, # source owned, payload data since [#50666] and kept as such
          'updated_at' => 6.days.ago # source owned, read as a delta filter
        }]
      }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      dump = load_item(object, 'st-1').dump['de']

      DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::INTERNAL_DUMP_KEYS.each do |key|
        next if key == 'dc_external_id' # ours, rebuilt from the external_id right after the strip

        assert_not dump.key?(key), "expected #{key} to be stripped from the dump"
      end

      assert_equal 'st-1', dump['dc_external_id']
      assert_equal 'Strip 1', dump['name']
      assert_equal 0, dump['priority']
      assert_predicate dump['updated_at'], :present?
    end

    test 'download_content stores no delete marker for a source that ships an explicit null' do
      # mongo's `$exists` counts a null, so a stored `deleted_at: nil` hid the item from every import
      object = download_object('dcf_strip_null')
      iterator = ->(**_kwargs) { [{ 'id' => 'sn-1', 'name' => 'Null marker', 'deleted_at' => nil, 'archived_at' => nil }] }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      dump = load_item(object, 'sn-1').dump['de']

      assert_not dump.key?('deleted_at')
      assert_not dump.key?('archived_at')
    end

    test 'download_content rewrites a dump that still carries a source owned delete marker' do
      # already stored items heal on their next download, so no data migration is needed
      object = download_object('dcf_strip_heal')
      seed_item(object, 'sh-1', {
        'de' => { 'id' => 'sh-1', 'name' => 'Heal me', 'dc_external_id' => 'sh-1', 'deleted_at' => 1.day.ago }
      })
      iterator = ->(**_kwargs) { [{ 'id' => 'sh-1', 'name' => 'Heal me', 'deleted_at' => 1.day.ago }] }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      dump = load_item(object, 'sh-1').dump['de']

      assert_not dump.key?('deleted_at')
      assert_equal 'Heal me', dump['name']
    end

    test 'download_content takes embedded credential keys from a string keyed external_system' do
      # a BSON::Document normalises the symbol, a plain Hash from a custom iterator does not
      object = download_object('dcf_str_cred')
      iterator = ->(**_kwargs) { [{ 'id' => 'sc-1', 'name' => 'SC 1', 'external_system' => { 'credential_keys' => ['str-cred'] } }] }

      SUBJECT.download_content(
        download_object: object,
        iterator:,
        data_id: ->(data) { data['id'] },
        data_name: ->(data) { data['name'] },
        options: { locales: [:de], download: {} }
      )

      item = load_item(object, 'sc-1')

      assert_includes item.external_system['credential_keys'], 'str-cred'
      assert_not item.dump['de'].key?('external_system')
    end

    test 'strip_internal_keys!: removes both key forms and keeps the receiver class' do
      bson = BSON::Document.new('id' => 'b-1', 'deleted_at' => 'x', 'mark_for_update' => 'x')

      assert_instance_of BSON::Document, SUBJECT.send(:strip_internal_keys!, bson)
      assert_equal BSON::Document.new('id' => 'b-1'), bson

      symbol_keyed = { id: 's-1', deleted_at: 'x', archived_at: 'x' }

      assert_equal({ id: 's-1' }, SUBJECT.send(:strip_internal_keys!, symbol_keyed))
    end

    test 'strip_internal_keys!: keeps source owned keys, tolerates a non hash' do
      payload = {
        'id' => 'k-1', 'name' => 'Keep', 'uri' => 'u', 'parent_id' => 'p', 'updated_at' => 't',
        'priority' => 3, 'tree_label' => 'Tags', 'concept_scheme_name' => 'Scheme',
        'external_id_prefix' => 'pre_', 'dc_step_priority' => 5, 'deleted_at' => 'x'
      }

      expected = payload.except('deleted_at', 'dc_step_priority') # before the in place strip

      assert_equal expected, SUBJECT.send(:strip_internal_keys!, payload)
      assert_equal 'not a hash', SUBJECT.send(:strip_internal_keys!, 'not a hash')
      assert_nil SUBJECT.send(:strip_internal_keys!, nil)
    end

    test 'download_content stores the claim from the step config, never the one in the payload' do
      # props_from_config is the only writer of the stored claim, so an upstream aggregation or a
      # dump to dump copy cannot hand a stale claim on to the next collection
      object = download_object('dcf_claim')
      iterator = ->(**_kwargs) { [{ 'id' => 'cl-1', 'name' => 'Claim 1', 'dc_step_priority' => 0 }] }

      2.times do # the step has to stay able to refresh what it claimed itself
        SUBJECT.download_content(
          download_object: object,
          iterator:,
          data_id: ->(data) { data['id'] },
          data_name: ->(data) { data['name'] },
          options: { locales: [:de], download: { priority: 2 } }
        )
      end

      assert_equal 2, load_item(object, 'cl-1').dump.dig('de', 'dc_step_priority')
    end

    test 'download_content keeps a configured claim and the source own priority side by side' do
      # [#50666] the bug itself: a step configuring `priority:` while the source ships a field of that
      # name (Intermaps SRM's display order). The claim goes to the namespaced key, the source's own
      # value stays payload data, and the step keeps writing what it claimed. Read the source's 0 back
      # as the claim and `2 <= 0` is false, so the second run is refused and the new name never lands
      # -- which is what froze those items.
      object = download_object('dcf_claim_both')

      ['Claim 1', 'Claim 1 renamed'].each do |name|
        SUBJECT.download_content(
          download_object: object,
          iterator: ->(**_kwargs) { [{ 'id' => 'cb-1', 'name' => name, 'priority' => 0, 'dc_step_priority' => 0 }] },
          data_id: ->(data) { data['id'] },
          data_name: ->(data) { data['name'] },
          options: { locales: [:de], download: { priority: 2 } }
        )
      end

      dump = load_item(object, 'cb-1').dump['de']

      assert_equal 2, dump['dc_step_priority'] # the configured claim, not the payload's 0
      assert_equal 0, dump['priority'] # source owned, untouched
      assert_equal 'Claim 1 renamed', dump['name'] # the second run was not refused
    end

    test 'with_default_step_priority: fills in the default only for a step that configures none' do
      subject = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy
      default = subject::DEFAULT_STEP_PRIORITY

      assert_equal default, subject.with_default_step_priority({ download: {} }).dig(:download, :priority)
      assert_equal 0, subject.with_default_step_priority({ download: { priority: 0 } }).dig(:download, :priority)
      assert_equal 2, subject.with_default_step_priority({ download: { priority: 2 } }).dig(:download, :priority)
    end

    test 'with_default_step_priority: the merged priority leaves the other config props reachable' do
      # deep_merge must merge *into* the existing :download. Had the options been string-keyed, the
      # merge would have added a second, symbol :download and props_from_config would have sliced that
      # one -- dropping tree_label and concept_scheme_name from every concept dump.
      options = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy.with_default_step_priority(
        { download: { tree_label: 'a label', concept_scheme_name: 'a scheme' } }
      )

      assert_equal(
        { 'tree_label' => 'a label', 'concept_scheme_name' => 'a scheme', 'dc_step_priority' => DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::DEFAULT_STEP_PRIORITY },
        SUBJECT.send(:props_from_config, options:)
      )
    end

    # item_allowed? decides whether the current step may (over)write the item already stored in the
    # target collection. A LOWER priority number means HIGHER priority.
    # The stored value lives under the namespaced dc_step_priority key.

    test 'item_allowed?: any step may write while no prioritised item is stored yet' do
      # a fresh record (or one written by an unprioritised step) has no claim, so anyone may write it
      assert SUBJECT.send(:item_allowed?, local_item: nil, options: {})
      assert SUBJECT.send(:item_allowed?, local_item: {}, options: { download: {} })
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: nil }, options: { download: { priority: 2 } })
    end

    test 'item_allowed?: an unprioritised step must not override a more prioritised item' do
      # this is the regression guard: e.g. an event step with no priority must not clobber a rich place
      assert_not SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: 0 }, options: { download: {} })
      assert_not SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: 1 }, options: { download: {} })
      assert_not SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: 2 }, options: { download: {} })
    end

    test 'item_allowed?: an unprioritised step runs at the default and may refresh a defaulted item' do
      # the concept pipelines stamp DEFAULT_STEP_PRIORITY on what they write; the step that produced
      # such an item configures no priority, so it has to stay able to write it again
      default = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::DEFAULT_STEP_PRIORITY

      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: default }, options: { download: {} })
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: default + 1 }, options: { download: {} })
      assert_not SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: default - 1 }, options: { download: {} })
    end

    test 'item_allowed?: a step of equal or higher priority (lower or equal number) may write' do
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: 2 }, options: { download: { priority: 0 } }) # higher
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: 2 }, options: { download: { priority: 2 } }) # equal
    end

    test 'item_allowed?: a step of lower priority (higher number) must not override' do
      # e.g. contributor (1) or location (2) may not overwrite a primary place (0)
      assert_not SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: 0 }, options: { download: { priority: 1 } })
      assert_not SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: 0 }, options: { download: { priority: 2 } })
      assert_not SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: 1 }, options: { download: { priority: 2 } })
    end

    test 'item_allowed?: reads the stored priority from a mongo-style BSON document with string keys' do
      stored = BSON::Document.new('dc_step_priority' => 0) # how the dump comes back from mongo

      assert_not SUBJECT.send(:item_allowed?, local_item: stored, options: { download: { priority: 1 } })
      assert SUBJECT.send(:item_allowed?, local_item: stored, options: { download: { priority: 0 } })
    end

    test "item_allowed?: a source-owned 'priority' field is not a step priority" do
      # [#50666] Intermaps SRM ships a display-order `priority` on every object. An unprioritised
      # step must stay free to refresh those items instead of freezing them.
      assert SUBJECT.send(:item_allowed?, local_item: { 'priority' => 1 }, options: { download: {} })
      assert SUBJECT.send(:item_allowed?, local_item: BSON::Document.new('priority' => 0), options: { download: {} })
      assert SUBJECT.send(:item_allowed?, local_item: { 'priority' => 0 }, options: { download: { priority: 2 } })
    end

    test 'item_allowed?: a stored value that is not a number is no claim at all' do
      # comparing it would raise and take the whole step down instead of just being ignored
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: 'high' }, options: { download: { priority: 2 } })
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: true }, options: { download: {} })
    end

    test 'item_allowed?: a numeric string is no claim and no step priority either' do
      # ExternalSystemStepContract rejects a quoted `priority:`, so nothing has to coerce one. Integer()
      # used to, but it took "2" and not "2.9" and truncated 2.9 to 2 -- a rule nobody could predict
      # from reading the value. A stored non-number is now no claim, an unreadable config runs at the
      # default, and neither can raise mid-step.
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: '1' }, options: { download: { priority: '2' } })
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: '0' }, options: { download: { priority: 2 } })
    end

    test 'item_allowed?: a float claim is compared as it is, not truncated' do
      # Integer(2.9) returned 2, which let a step at 2 write an item claimed at 2.9
      assert_not SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: 1.5 }, options: { download: { priority: 2 } })
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: 2.5 }, options: { download: { priority: 2 } })
    end

    test 'item_allowed?: a step priority that is not a number falls back to the default' do
      # to_i would return 0, which is the highest priority there is
      default = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::DEFAULT_STEP_PRIORITY

      assert_not SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: default - 1 }, options: { download: { priority: nil } })

      assert_not SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: default - 1 }, options: { download: { priority: 'top' } })
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: default }, options: { download: { priority: 'top' } })
    end

    test 'item_allowed?: a configured priority above the default is clamped down to it' do
      # ExternalSystemStepContract rejects one, but it only runs at config import and nothing
      # re-validates a stored download_config. Unclamped, such a step wrote items no step had claimed
      # while items claimed at the default stayed closed to it -- the equivalence the design rests on
      # ("no claim" == "claim = the default") broke exactly there.
      default = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::DEFAULT_STEP_PRIORITY
      over = { download: { priority: default + 4 } }

      assert SUBJECT.send(:item_allowed?, local_item: nil, options: over)
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: default }, options: over)
      assert_not SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: default - 1 }, options: over)
    end

    test 'props_from_config: a claim outside the contract range is clamped, gate and claim alike' do
      # Clamping only the gate would invent a freeze: a step configured at -1 claims -1, its own gate
      # clamps to 0, and 0 <= -1 refuses the next write -- it locks itself out of its own items.
      default = DataCycleCore::Generic::Common::Extensions::DumpKeyPolicy::DEFAULT_STEP_PRIORITY
      under = { download: { priority: -1 } }

      assert_equal({ 'dc_step_priority' => default }, SUBJECT.send(:props_from_config, options: { download: { priority: default + 4 } }))

      props = SUBJECT.send(:props_from_config, options: under)

      assert_equal({ 'dc_step_priority' => 0 }, props)
      assert SUBJECT.send(:item_allowed?, local_item: { dc_step_priority: props['dc_step_priority'] }, options: under)
    end

    test 'props_from_config: a configured priority is stored under the namespaced key' do
      props = SUBJECT.send(:props_from_config, options: { download: { priority: 2, tree_label: 'a label' } })

      assert_equal({ 'dc_step_priority' => 2, 'tree_label' => 'a label' }, props)
      assert_not props.key?('priority')
    end

    test 'props_from_config: steps without a priority stay free of the key' do
      assert_equal({ 'tree_label' => 'a label' }, SUBJECT.send(:props_from_config, options: { download: { tree_label: 'a label' } }))
      assert_empty SUBJECT.send(:props_from_config, options: { download: {} })
      # an empty `priority:` is a present key with no value; the contract rejects one now, but a
      # download_config stored before that rule would otherwise stamp an explicit null into every dump
      assert_empty SUBJECT.send(:props_from_config, options: { download: { priority: nil } })
    end
  end
end
