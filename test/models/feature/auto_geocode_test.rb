# frozen_string_literal: true

require 'test_helper'

# The geocode provider lives in a separate plugin gem (datacycle-feature-geocode) that is NOT
# loaded in data-cycle-core's standalone test environment, so DataCycleCore::Feature['Geocode']
# is nil here. AutoGeocode only depends on it via a defensive runtime lookup (Feature['Geocode']
# &.enabled?), so we provide a minimal stand-in to exercise the feature in isolation. When the
# real plugin IS loaded (e.g. inside a host project) Feature['Geocode'] resolves to it instead
# and this stub is never defined.
unless DataCycleCore::Feature['Geocode']
  module DataCycleCore
    module Feature
      class Geocode < Base
        # overridden per-test via AutoGeocodeFeatureTest#stub_geocode_address
        def self.geocode_address(_address, _locale = I18n.locale)
          {}
        end

        # mirrors the real geocode feature (datacycle-feature-geocode): AutoGeocode falls back to this
        # for its geo target when :auto_geocode: sets no :target_key: of its own. (attribute_keys is
        # inherited from Feature::Base.)
        def self.target_key(content = nil)
          configuration(content)['target_key']
        end

        # mirrors Datacycle::Feature::Geocode::Base: AutoGeocode delegates the "is this address precise
        # enough" heuristic here, so the stub has to answer it too.
        def self.street_address_with_house_number?(street_address)
          street_address.to_s.match?(/\d/)
        end
      end
    end
  end
end

module DataCycleCore
  class AutoGeocodeFeatureTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # Place carries address + geo and opts into :auto_geocode in its test data definition -> geocodable
    GEOCODE_TEMPLATE = 'Örtlichkeit'
    # Tour is a Place subtype (schema_ancestors: Place) that also opts into :auto_geocode but carries
    # no postal_address -> allowed?/geocodable? must exclude it (the "Trail despite extending Place" case)
    NON_GEOCODABLE_PLACE_TEMPLATE = 'Tour'
    # image is not a place, does not opt in, has no address/geo -> never geocodable
    NON_GEOCODABLE_TEMPLATE = 'Bild'
    # event has no own address -> not directly geocodable; its content_location (a Place) is geocodable on its own save
    EVENT_TEMPLATE = 'Event'
    TAG_TREE = 'Geocoding'
    TAG_ALIAS = 'geocoded'
    ADDRESS = {
      'street_address' => 'Hauptplatz 1',
      'postal_code' => '6900',
      'address_locality' => 'Bregenz'
    }.freeze
    # street without a house number: the geocoder would answer with a street/village centroid, which
    # the customer explicitly rejected (#45442) -> must be treated as insufficient
    ADDRESS_WITHOUT_HOUSE_NUMBER = ADDRESS.merge('street_address' => 'Hauptplatz').freeze

    # minimal host to exercise the post-save hook in isolation (without booting the whole Thing save
    # lifecycle). The hook's per-content decisions (#queue_geocoding? etc.) are now instance methods,
    # so #build_hook_host stubs them per-instance via singleton methods (which override the prepended
    # module) and #remove_auto_geocoded_tag records the contents it was called on.
    class HookHost
      attr_accessor :id, :previous_datahash_changes
      attr_reader :removed_tags

      def initialize
        @removed_tags = []
      end

      def embedded?
        false
      end

      # base implementation the prepended module calls via `super`
      def after_save_data_hash(_options)
      end

      prepend DataCycleCore::Feature::DataHash::AutoGeocode
    end

    # DataCycleCore.features is frozen at the top level, but the nested feature hashes can be
    # mutated in place (same approach as the other feature tests).
    before(:all) do
      @geocode_enabled = DataCycleCore.features[:geocode][:enabled]
      @geocode_attribute_keys = DataCycleCore.features[:geocode][:attribute_keys]&.deep_dup
      @geocode_target_key = DataCycleCore.features[:geocode][:target_key]
      @auto_geocode_config = DataCycleCore.features[:auto_geocode].slice(:enabled, :allowed, :attribute_keys, :target_key)

      DataCycleCore.features[:geocode][:enabled] = true
      DataCycleCore.features[:geocode][:attribute_keys] = ['address']
      DataCycleCore.features[:geocode][:target_key] = 'location'

      # Mirror production: :auto_geocode: sets no :attribute_keys: / :target_key: of its own, so it
      # reuses the geocode feature's (address -> location). Realistic per-template opt-in: the global
      # :allowed stays false (the production default); the test templates opt in via their data
      # definitions (e.g. Place sets :features: :auto_geocode: :allowed: true).
      DataCycleCore.features[:auto_geocode].merge!(
        enabled: true,
        allowed: false,
        attribute_keys: nil,
        target_key: nil
      )

      DataCycleCore::Feature['Geocode'].reload
      DataCycleCore::Feature::AutoGeocode.reload

      # The geocoding behaviour now lives as instance methods on the content (DataHash::AutoGeocode),
      # so the module must be woven into the real content lifecycle for the tests that drive a content
      # directly (content.geocodable? etc.). In the gem's standalone test env auto_geocode ships
      # disabled, so the boot-time prepend in Content::DataHash was skipped; this reproduces what a
      # host app does at boot. prepend is idempotent and intentionally not undone (Ruby cannot cleanly
      # un-prepend) - the hook early-returns once the feature is disabled again in after(:all).
      DataCycleCore::Content::DataHash.prepend(DataCycleCore::Feature::AutoGeocode.data_hash_module)
    end

    after(:all) do
      DataCycleCore.features[:geocode][:enabled] = @geocode_enabled
      DataCycleCore.features[:geocode][:attribute_keys] = @geocode_attribute_keys
      DataCycleCore.features[:geocode][:target_key] = @geocode_target_key
      DataCycleCore.features[:auto_geocode].merge!(@auto_geocode_config)
      DataCycleCore::Feature['Geocode'].reload
      DataCycleCore::Feature::AutoGeocode.reload
    end

    # --- enablement & geocodable? ----------------------------------------------------------

    test 'feature is enabled (and its geocode dependency is satisfied)' do
      assert_predicate DataCycleCore::Feature::AutoGeocode, :enabled?
    end

    test 'attribute_keys and target_key fall back to the geocode feature when :auto_geocode: sets none' do
      # mirrors production: :auto_geocode: declares no :attribute_keys: / :target_key:, so it reuses
      # the geocode feature's - changing geocode's here is reflected on auto_geocode.
      with_geocode_geo_attributes(attribute_keys: ['postal_address'], target_key: 'geo_point') do
        assert_equal ['postal_address'], DataCycleCore::Feature::AutoGeocode.attribute_keys
        assert_equal 'geo_point', DataCycleCore::Feature::AutoGeocode.target_key
      end
    end

    test 'an explicit :auto_geocode: attribute_keys / target_key overrides the geocode default' do
      with_auto_geocode_geo_attributes(attribute_keys: ['custom_address'], target_key: 'custom_location') do
        assert_equal ['custom_address'], DataCycleCore::Feature::AutoGeocode.attribute_keys
        assert_equal 'custom_location', DataCycleCore::Feature::AutoGeocode.target_key
      end
    end

    test 'a content with address + geo attributes is geocodable' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant geocodable', address: ADDRESS })

      assert_predicate content, :geocodable?
    end

    test 'a content without address/geo attributes is not geocodable' do
      content = create_content(NON_GEOCODABLE_TEMPLATE, { name: 'Just an image' })

      assert_not content.geocodable?
    end

    test 'an event is not directly geocodable (no address of its own); its venue is, on its own save' do
      venue = create_content(GEOCODE_TEMPLATE, { name: 'Venue', address: ADDRESS })
      event = create_content(EVENT_TEMPLATE, { name: 'Concert', content_location: [venue.id] })

      assert_not event.geocodable?, 'event itself carries no address'
      assert_predicate venue, :geocodable?, 'the venue (a geocodable template) is geocodable on its own'
    end

    test 'a Place subtype that carries no address (Tour) is not allowed, though Place is' do
      place = create_content(GEOCODE_TEMPLATE, { name: 'Geocodable Place', address: ADDRESS })
      tour = create_content(NON_GEOCODABLE_PLACE_TEMPLATE, { name: 'Tour without an address' })

      assert DataCycleCore::Feature::AutoGeocode.allowed?(place), 'Place opts in and carries address + geo'
      assert_not DataCycleCore::Feature::AutoGeocode.allowed?(tour), 'Tour has no address'
      assert_not tour.geocodable?
    end

    # --- sufficient_address? (only geocode addresses that yield a meaningful position) -------

    test 'sufficient_address? accepts a street-level address' do
      assert DataCycleCore::Feature::AutoGeocode.sufficient_address?(ADDRESS)
    end

    test 'sufficient_address? rejects a street without a house number' do
      assert_not DataCycleCore::Feature::AutoGeocode.sufficient_address?(ADDRESS_WITHOUT_HOUSE_NUMBER)
    end

    test 'sufficient_address? rejects an address without a street' do
      assert_not DataCycleCore::Feature::AutoGeocode.sufficient_address?(ADDRESS.except('street_address'))
    end

    test 'sufficient_address? rejects an address without postal code or locality' do
      assert_not DataCycleCore::Feature::AutoGeocode.sufficient_address?(ADDRESS.except('postal_code'))
      assert_not DataCycleCore::Feature::AutoGeocode.sufficient_address?(ADDRESS.except('address_locality'))
    end

    # --- auto_geocode_needed? --------------------------------------------------------------

    test 'auto_geocode_needed? is true for a geocodable content with a sufficient address and no coordinates' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Needed Yes', address: ADDRESS })

      assert_predicate content, :auto_geocode_needed?
    end

    test 'auto_geocode_needed? is false without an address' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Needed No Address' })

      assert_not content.auto_geocode_needed?
    end

    test 'auto_geocode_needed? is false for an address that yields no meaningful position' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Needed Imprecise', address: ADDRESS_WITHOUT_HOUSE_NUMBER })

      assert_not content.auto_geocode_needed?
    end

    test 'auto_geocode_needed? is false when authoritative coordinates already exist' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Needed Has Coords', address: ADDRESS, location: sample_point })

      assert_not content.auto_geocode_needed?
    end

    test 'auto_geocode_needed? is false for a content whose template does not opt in' do
      content = create_content(NON_GEOCODABLE_TEMPLATE, { name: 'Needed Not Allowed' })

      assert_not content.auto_geocode_needed?
    end

    # --- scope of auto-geocodable content (used by the backfill task / data migration) -------

    test 'allowed_template_names lists the opted-in templates and auto_geocodable_things scopes to them' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Scoped Place', address: ADDRESS })
      tour = create_content(NON_GEOCODABLE_PLACE_TEMPLATE, { name: 'Scoped Tour' })

      template_names = DataCycleCore::Feature::AutoGeocode.allowed_template_names

      assert_includes template_names, content.template_name
      assert_not_includes template_names, tour.template_name

      things = DataCycleCore::Feature::AutoGeocode.auto_geocodable_things

      assert_includes things.pluck(:id), content.id
      assert_not_includes things.pluck(:id), tour.id
    end

    test 'backfill enqueues only the contents that need geocoding and counts the rest by reason' do
      needed = create_content(GEOCODE_TEMPLATE, { name: 'Backfill Needed', address: ADDRESS })
      imprecise = create_content(GEOCODE_TEMPLATE, { name: 'Backfill Imprecise', address: ADDRESS_WITHOUT_HOUSE_NUMBER })
      done = create_content(GEOCODE_TEMPLATE, { name: 'Backfill Done', address: ADDRESS, location: sample_point })
      contents = DataCycleCore::Thing.where(id: [needed.id, imprecise.id, done.id])

      stats = nil
      enqueued = capture_perform_later do
        stats = DataCycleCore::Feature::AutoGeocode.backfill(contents)
      end

      assert_equal [[needed.id]], enqueued
      assert_equal 1, stats[:needed]
      assert_equal 1, stats[:insufficient_address]
      assert_equal 1, stats[:has_coordinates]
      assert_equal 0, stats[:errors]
      assert_includes DataCycleCore::Feature::AutoGeocode.backfill_summary(stats), '3 contents checked'
    end

    test 'backfill does not re-enqueue content it already geocoded, but the hook still refreshes it' do
      create_auto_geocoded_tag
      content = create_content(GEOCODE_TEMPLATE, { name: 'Backfill Already Geocoded', address: ADDRESS })
      stub_geocode_address(sample_point) { content.auto_geocode! }
      content.reload

      assert_equal :refreshable, content.auto_geocode_status
      assert content.queue_geocoding?(['address']), 'an address change must still refresh coordinates we own'

      stats = nil
      enqueued = capture_perform_later do
        stats = DataCycleCore::Feature::AutoGeocode.backfill(DataCycleCore::Thing.where(id: content.id))
      end

      assert_empty enqueued, 'the backfill fills gaps; it must not re-geocode what it already geocoded'
      assert_equal 1, stats[:refreshable]
    end

    test 'backfill re-raises a database error instead of swallowing it' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Backfill DB Error', address: ADDRESS })

      # A failed statement leaves a surrounding transaction unusable (the backfill also runs from a
      # data migration), so counting it as one content's error would make every later query fail with
      # PG::InFailedSqlTransaction and hide the real cause.
      stub_perform_later_raising(ActiveRecord::StatementInvalid.new('PG::UndefinedTable')) do
        assert_raises ActiveRecord::StatementInvalid do
          DataCycleCore::Feature::AutoGeocode.backfill(DataCycleCore::Thing.where(id: content.id))
        end
      end
    end

    test 'backfill counts a non-database error per content and logs it, keeping the batch going' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Backfill Soft Error', address: ADDRESS })
      log = []
      logger = Object.new
      logger.define_singleton_method(:error) { |message| log << message }

      stats = stub_perform_later_raising(RuntimeError.new('boom')) do
        DataCycleCore::Feature::AutoGeocode.backfill(DataCycleCore::Thing.where(id: content.id), logger:)
      end

      assert_equal 1, stats[:errors]
      assert_equal 1, log.size
      assert_includes log.first, content.id
      assert_includes log.first, 'boom'
    end

    test 'backfill in dry_run mode counts without enqueuing' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Backfill Dry', address: ADDRESS })
      contents = DataCycleCore::Thing.where(id: content.id)

      stats = nil
      enqueued = capture_perform_later do
        stats = DataCycleCore::Feature::AutoGeocode.backfill(contents, dry_run: true)
      end

      assert_empty enqueued
      assert_equal 1, stats[:needed]
      assert_includes DataCycleCore::Feature::AutoGeocode.backfill_summary(stats, dry_run: true), 'would be enqueued'
    end

    test 'backfill counts the enqueues the queue accepted, not the duplicates it dropped' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Backfill Duplicate', address: ADDRESS })

      # AutoGeocodeThingJob is a UniqueApplicationJob: for a content that already has a duplicate
      # waiting, abort_if_queued throws :abort and perform_later answers false instead of a job
      stats = stub_perform_later_returning(false) do
        DataCycleCore::Feature::AutoGeocode.backfill(DataCycleCore::Thing.where(id: content.id))
      end
      summary = DataCycleCore::Feature::AutoGeocode.backfill_summary(stats)

      assert_equal 1, stats[:needed]
      assert_equal 0, stats[:enqueued]
      assert_includes summary, '1 contents checked'
      assert_includes summary, '0 enqueued'
      assert_includes summary, '1 already had a job queued'
    end

    # --- queue_geocoding? decision ---------------------------------------------------------

    test 'queues geocoding when the address changed and no coordinates exist yet' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant A', address: ADDRESS })

      assert content.queue_geocoding?(['address'])
    end

    test 'does not queue geocoding when coordinates already exist' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant B', address: ADDRESS, location: sample_point })

      assert_not content.queue_geocoding?(['address'])
    end

    test 'does not queue geocoding when the address did not change' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant C', address: ADDRESS })

      assert_not content.queue_geocoding?(['name'])
    end

    test 'does not queue geocoding for an address that yields no meaningful position' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant Imprecise', address: ADDRESS_WITHOUT_HOUSE_NUMBER })

      assert_not content.queue_geocoding?(['address']),
                 'an address the geocoder could only answer with a street/village centroid must not even be queued'
    end

    # --- auto_geocode! ---------------------------------------------------------------------

    test 'auto_geocode! writes the resolved coordinates back to the content' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant D', address: ADDRESS })

      stub_geocode_address(sample_point) do
        content.auto_geocode!
      end

      content.reload

      assert_predicate content.location, :present?
      assert_in_delta 47.50311, content.latitude.to_f, 0.0001
      assert_in_delta 9.74965, content.longitude.to_f, 0.0001
    end

    test 'auto_geocode! does not touch authoritative coordinates (i.e. the set outside auto-geocoding)' do
      existing = sample_point
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant E', address: ADDRESS, location: existing })

      stub_geocode_address(other_point) do
        assert_not content.auto_geocode!
      end

      content.reload

      assert_in_delta existing.y, content.latitude.to_f, 0.0001
      assert_in_delta existing.x, content.longitude.to_f, 0.0001
    end

    test 'auto_geocode! does nothing when the address is incomplete' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant Incomplete', address: { 'address_locality' => 'Bregenz' } })

      stub_geocode_address(sample_point) do
        assert_not content.auto_geocode!
      end

      assert_nil content.reload.location
    end

    test 'auto_geocode! does nothing when the street address carries no house number' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant Centroid', address: ADDRESS_WITHOUT_HOUSE_NUMBER })

      stub_geocode_address(sample_point) do
        assert_not content.auto_geocode!
      end

      assert_nil content.reload.location
    end

    # --- re-geocoding ownership (only refresh coordinates we set ourselves) -----------------

    test 're-geocodes content whose existing coordinates were auto-geocoded' do
      create_auto_geocoded_tag
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant Reauto', address: ADDRESS })

      # first pass fills coordinates and tags the content as auto-geocoded
      stub_geocode_address(sample_point) do
        content.auto_geocode!
      end
      content.reload

      assert content.queue_geocoding?(['address']),
             'auto-geocoded content should re-geocode on an address change'

      # second pass: address changed -> re-derive coordinates (overwriting our own)
      stub_geocode_address(other_point) do
        content.auto_geocode!
      end

      content.reload

      assert_in_delta other_point.y, content.latitude.to_f, 0.0001
      assert_in_delta other_point.x, content.longitude.to_f, 0.0001
    end

    test 'does not re-geocode content whose coordinates are authoritative (not auto-geocoded)' do
      create_auto_geocoded_tag
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant Authoritative', address: ADDRESS, location: sample_point })

      assert_not content.queue_geocoding?(['address'])

      stub_geocode_address(other_point) do
        assert_not content.auto_geocode!
      end

      content.reload

      assert_in_delta sample_point.y, content.latitude.to_f, 0.0001
      assert_in_delta sample_point.x, content.longitude.to_f, 0.0001
    end

    # --- tagging ---------------------------------------------------------------------------

    test 'auto_geocode! tags the content with the auto-geocoded classification' do
      tag_ids = create_auto_geocoded_tag

      assert_predicate tag_ids, :present?

      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant F', address: ADDRESS })

      stub_geocode_address(sample_point) do
        content.auto_geocode!
      end

      assert_equal tag_ids.sort, (content.reload.universal_classifications.pluck(:id) & tag_ids).sort
    end

    test 'auto_geocode! leaves classifications untouched when geocoded classification is unavailable' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant G', address: ADDRESS })
      before_ids = content.universal_classifications.pluck(:id).sort

      with_geocoded_classification_ids([]) do
        stub_geocode_address(sample_point) do
          content.auto_geocode!
        end
      end

      assert_equal before_ids, content.reload.universal_classifications.pluck(:id).sort
    end

    # --- stale ownership tag cleanup -------------------------------------------------------

    test 'cleanup_stale_tag? flags a tagged content whose coordinates are gone' do
      tag_ids = create_auto_geocoded_tag
      content = create_content(GEOCODE_TEMPLATE, { name: 'Stale Tagged', address: ADDRESS })
      tag_content(content, tag_ids)

      assert content.cleanup_stale_tag?(['location'])
    end

    test 'cleanup_stale_tag? is false while the coordinates are still present' do
      tag_ids = create_auto_geocoded_tag
      content = create_content(GEOCODE_TEMPLATE, { name: 'Tagged With Coords', address: ADDRESS, location: sample_point })
      tag_content(content, tag_ids)

      assert_not content.cleanup_stale_tag?(['location'])
    end

    test 'cleanup_stale_tag? is false when the geo target did not change in the save' do
      tag_ids = create_auto_geocoded_tag
      content = create_content(GEOCODE_TEMPLATE, { name: 'Stale Untouched', address: ADDRESS })
      tag_content(content, tag_ids)

      assert_not content.cleanup_stale_tag?(['name'])
    end

    test 'cleanup_stale_tag? is false for content that never carried the auto-geocoded tag' do
      create_auto_geocoded_tag
      content = create_content(GEOCODE_TEMPLATE, { name: 'Untagged No Coords', address: ADDRESS })

      assert_not content.cleanup_stale_tag?(['location'])
    end

    test 'remove_auto_geocoded_tag drops only the auto-geocoded tag' do
      tag_ids = create_auto_geocoded_tag
      content = create_content(GEOCODE_TEMPLATE, { name: 'To Untag', address: ADDRESS })
      tag_content(content, tag_ids)

      assert_predicate(content.universal_classifications.pluck(:id) & tag_ids, :present?)

      content.remove_auto_geocoded_tag

      assert_empty(content.reload.universal_classifications.pluck(:id) & tag_ids)
    end

    test 'remove_auto_geocoded_tag is a no-op when geocoded classification is unavailable' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'No Tag Config', address: ADDRESS })
      before_ids = content.universal_classifications.pluck(:id).sort

      with_geocoded_classification_ids([]) do
        assert_not content.remove_auto_geocoded_tag
      end
      assert_equal before_ids, content.reload.universal_classifications.pluck(:id).sort
    end

    # --- background job --------------------------------------------------------------------

    test 'AutoGeocodeThingJob geocodes the given content' do
      content = create_content(GEOCODE_TEMPLATE, { name: 'Restaurant H', address: ADDRESS })

      stub_geocode_address(sample_point) do
        DataCycleCore::AutoGeocodeThingJob.perform_now(content.id)
      end

      assert_predicate content.reload.location, :present?
    end

    test 'AutoGeocodeThingJob is a no-op for a missing content id' do
      assert_nothing_raised do
        DataCycleCore::AutoGeocodeThingJob.perform_now('00000000-0000-0000-0000-000000000000')
      end
    end

    # UniqueApplicationJob#abort_if_queued keys off concurrency_key, so without limits_concurrency
    # the per-content deduplication this feature relies on silently does nothing
    test 'AutoGeocodeThingJob limits concurrency per content id' do
      job = DataCycleCore::AutoGeocodeThingJob.new('thing-1')

      assert_equal 'DataCycleCore::AutoGeocodeThingJob/thing-1', job.concurrency_key
      assert_not_equal job.concurrency_key, DataCycleCore::AutoGeocodeThingJob.new('thing-2').concurrency_key
    end

    # the priority must live in ActiveJob's attribute, not in an overridden reader, so that
    # JobExtensions::Callbacks can lower it between retries
    test 'AutoGeocodeThingJob priority is settable and survives a bump' do
      job = DataCycleCore::AutoGeocodeThingJob.new('thing-1')

      assert_equal DataCycleCore::AutoGeocodeThingJob::PRIORITY, job.priority

      job.priority += 1

      assert_equal DataCycleCore::AutoGeocodeThingJob::PRIORITY + 1, job.priority
    end

    # --- post-save hook --------------------------------------------------------------------

    test 'post-save hook enqueues the job (with the content id) when geocoding is needed' do
      host = build_hook_host(id: 'thing-1', changes: { 'address' => [] }, queue: true)

      enqueued = capture_perform_later { host.after_save_data_hash(nil) }

      assert_equal [['thing-1']], enqueued
    end

    test 'post-save hook does not enqueue when geocoding is not needed' do
      host = build_hook_host(id: 'thing-1', changes: {}, queue: false)

      enqueued = capture_perform_later { host.after_save_data_hash(nil) }

      assert_empty enqueued
    end

    test 'post-save hook removes the stale tag (without enqueuing) when coordinates were cleared' do
      host = build_hook_host(id: 'thing-1', changes: { 'location' => [] }, queue: false, stale: true)

      enqueued = capture_perform_later { host.after_save_data_hash(nil) }

      assert_empty enqueued
      assert_equal [host], host.removed_tags
    end

    test 'integration: a real save of a geocodable content fires the feature.data_hash_module hook prepended into the content lifecycleand enqueues the job' do
      ensure_hook_prepended

      content = nil
      enqueued = capture_perform_later do
        content = create_content(GEOCODE_TEMPLATE, { name: 'Hook Integration', address: ADDRESS })
      end

      assert_includes enqueued.map(&:first), content.id
    end

    test 'integration: an import-style save (new_content, no history) enqueues the job exactly once' do
      ensure_hook_prepended

      content = DataCycleCore::Thing.new(thing_template: DataCycleCore::ThingTemplate.find_by(template_name: GEOCODE_TEMPLATE))
      content.save!

      enqueued = capture_perform_later do
        content.set_data_hash(
          data_hash: { 'name' => 'Imported POI', 'address' => ADDRESS },
          new_content: true,
          prevent_history: true,
          update_search_all: true
        )
      end

      assert_includes content.previous_datahash_changes.keys, 'address',
                      'the watched address key must show up in the diff of a fresh import'
      assert_equal [[content.id]], enqueued
    end

    test 'integration: an import-style save with an imprecise address enqueues nothing' do
      ensure_hook_prepended

      content = DataCycleCore::Thing.new(thing_template: DataCycleCore::ThingTemplate.find_by(template_name: GEOCODE_TEMPLATE))
      content.save!

      enqueued = capture_perform_later do
        content.set_data_hash(
          data_hash: { 'name' => 'Imported POI without house number', 'address' => ADDRESS_WITHOUT_HOUSE_NUMBER },
          new_content: true,
          prevent_history: true,
          update_search_all: true
        )
      end

      assert_empty enqueued
    end

    test 'integration: clearing coordinates on a real auto-geocoded content removes the tag via the prepended hook (synchronous cleanup)' do
      ensure_hook_prepended
      tag_ids = create_auto_geocoded_tag

      content = create_content(GEOCODE_TEMPLATE, { name: 'Real Cleared', address: ADDRESS })
      stub_geocode_address(sample_point) do
        content.auto_geocode!
      end
      content.reload

      assert_predicate(content.universal_classifications.pluck(:id) & tag_ids, :present?)

      content.set_data_hash(data_hash: { 'location' => nil, 'latitude' => nil, 'longitude' => nil }, prevent_history: true)

      assert_empty(content.reload.universal_classifications.pluck(:id) & tag_ids)
    end

    private

    # Weaves the feature's data_hash_module into the real content lifecycle. In the gem's standalone
    # test env auto_geocode ships disabled, so the boot-time prepend in Content::DataHash was skipped;
    # this reproduces what a host app does at boot when the feature is enabled. Idempotent. The prepend
    # is intentionally not undone (Ruby cannot cleanly un-prepend) - it is inert once the feature is
    # disabled again in after(:all) (the hook's branches all early-return when not enabled/configured).
    def ensure_hook_prepended
      base = DataCycleCore::Content::DataHash
      hook = DataCycleCore::Feature::AutoGeocode.data_hash_module
      base.prepend(hook) unless base.ancestors.include?(hook)
    end

    def sample_point
      RGeo::Geographic.spherical_factory(srid: 4326).point(9.74965, 47.50311)
    end

    def other_point
      RGeo::Geographic.spherical_factory(srid: 4326).point(16.37380, 48.20817)
    end

    # temporarily replaces the (Toursprung-backed) Geocode endpoint with a fixed result
    def stub_geocode_address(point)
      geocode = DataCycleCore::Feature['Geocode']
      original = geocode.method(:geocode_address)
      geocode.define_singleton_method(:geocode_address) { |*_args| point }
      yield
    ensure
      geocode.define_singleton_method(:geocode_address, original)
    end

    # records arguments passed to AutoGeocodeThingJob.perform_later (avoids depending on the queue
    # adapter the suite happens to run, and on what the job itself does on the way in)
    def capture_perform_later
      calls = []
      job = DataCycleCore::AutoGeocodeThingJob
      original = job.method(:perform_later)
      job.define_singleton_method(:perform_later) { |*args| calls << args }
      yield
      calls
    ensure
      job.define_singleton_method(:perform_later, original)
    end

    # makes AutoGeocodeThingJob.perform_later answer a fixed value, to exercise the backfill against
    # an enqueue that was aborted (false) without building the queue rows that abort it
    def stub_perform_later_returning(value)
      job = DataCycleCore::AutoGeocodeThingJob
      original = job.method(:perform_later)
      job.define_singleton_method(:perform_later) { |*_args| value }
      yield
    ensure
      job.define_singleton_method(:perform_later, original)
    end

    # makes AutoGeocodeThingJob.perform_later raise, to exercise the backfill's error handling
    def stub_perform_later_raising(error)
      job = DataCycleCore::AutoGeocodeThingJob
      original = job.method(:perform_later)
      job.define_singleton_method(:perform_later) { |*_args| raise error }
      yield
    ensure
      job.define_singleton_method(:perform_later, original)
    end

    # builds a HookHost with its per-content decisions (now instance methods) stubbed via singleton
    # methods, which override the prepended module - so the hook's branching can be tested without a
    # real Thing. remove_auto_geocoded_tag records the contents it is called on (host.removed_tags).
    def build_hook_host(id:, changes:, queue: false, stale: false)
      host = HookHost.new
      host.id = id
      host.previous_datahash_changes = changes
      host.define_singleton_method(:queue_geocoding?) { |_changed| queue }
      host.define_singleton_method(:cleanup_stale_tag?) { |_changed| stale }
      host.define_singleton_method(:remove_auto_geocoded_tag) { @removed_tags << self }
      host
    end

    # tags a content with the given classification ids (simulates a prior auto-geocode tagging)
    def tag_content(content, tag_ids)
      content.set_data_hash(
        data_hash: { 'universal_classifications' => (content.universal_classifications.pluck(:id) + tag_ids).uniq },
        prevent_history: true
      )
      content.reload
    end

    # ensures the Geocoding/geocoded classification exists and returns the ids it resolves to.
    # Idempotent across re-runs.
    def create_auto_geocoded_tag
      tree = DataCycleCore::ClassificationTreeLabel.find_by(name: TAG_TREE) ||
             DataCycleCore::ClassificationTreeLabel.create(name: TAG_TREE, visibility: ['show', 'edit', 'api'])
      tree.create_classification_alias({ name: TAG_ALIAS, internal: true }) if DataCycleCore::Concept.for_tree(TAG_TREE).with_internal_name(TAG_ALIAS).blank?

      DataCycleCore::Concept.for_tree(TAG_TREE).with_internal_name(TAG_ALIAS).pluck(:classification_id)
    end

    # temporarily overrides the geocode feature's address source + geo target (which auto_geocode
    # reuses by default, when :auto_geocode: sets none of its own)
    def with_geocode_geo_attributes(attribute_keys:, target_key:)
      previous_keys = DataCycleCore.features[:geocode][:attribute_keys]&.deep_dup
      previous_target = DataCycleCore.features[:geocode][:target_key]
      DataCycleCore.features[:geocode].merge!(attribute_keys:, target_key:)
      DataCycleCore::Feature['Geocode'].reload
      DataCycleCore::Feature::AutoGeocode.reload
      yield
    ensure
      DataCycleCore.features[:geocode].merge!(attribute_keys: previous_keys, target_key: previous_target)
      DataCycleCore::Feature['Geocode'].reload
      DataCycleCore::Feature::AutoGeocode.reload
    end

    # temporarily sets an explicit :auto_geocode: address source + geo target (overriding the geocode
    # default)
    def with_auto_geocode_geo_attributes(attribute_keys:, target_key:)
      previous_keys = DataCycleCore.features[:auto_geocode][:attribute_keys]
      previous_target = DataCycleCore.features[:auto_geocode][:target_key]
      DataCycleCore.features[:auto_geocode].merge!(attribute_keys:, target_key:)
      DataCycleCore::Feature::AutoGeocode.reload
      yield
    ensure
      DataCycleCore.features[:auto_geocode].merge!(attribute_keys: previous_keys, target_key: previous_target)
      DataCycleCore::Feature::AutoGeocode.reload
    end

    # temporarily overrides the resolved geocoded classification ids.
    def with_geocoded_classification_ids(ids)
      feature = DataCycleCore::Feature::AutoGeocode
      original = feature.method(:geocoded_classification_ids)
      feature.define_singleton_method(:geocoded_classification_ids) { ids }
      yield
    ensure
      feature.define_singleton_method(:geocoded_classification_ids, original)
    end
  end
end
