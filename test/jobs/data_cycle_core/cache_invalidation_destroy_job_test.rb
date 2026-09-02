# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # The concurrency key is the only thing UniqueApplicationJob dedups by, so what it does and does not
  # distinguish decides which enqueues collapse into one job.
  class CacheInvalidationDestroyJobTest < DataCycleCore::TestCases::ActiveSupportTestCase
    ALIAS_ID = '00000000-0000-0000-0000-000000000001'
    THING_IDS = Array.new(3) { |i| "00000000-0000-0000-0000-00000000010#{i}" }

    def key_for(things_ids, method_name: 'update_things_search')
      DataCycleCore::CacheInvalidationDestroyJob
        .new('DataCycleCore::ClassificationAlias', ALIAS_ID, method_name, things_ids)
        .concurrency_key
    end

    # the callers pluck the ids without an ORDER BY, so the same contents can arrive in any order —
    # an order-sensitive key would stop deduplicating exactly for the large sets that need it most
    test 'the key identifies the set of contents, not the order they arrive in' do
      assert_equal(key_for(THING_IDS), key_for(THING_IDS.reverse))
    end

    test 'a different set of contents gets a different key' do
      assert_not_equal(key_for(THING_IDS), key_for(THING_IDS.take(2)))
    end

    test 'the same contents on a different side effect get different keys' do
      assert_not_equal(key_for(THING_IDS), key_for(THING_IDS, method_name: 'update_things_computed_properties'))
    end

    # solid_queue_jobs.concurrency_key is btree-indexed and rejects an index row over 2704 bytes,
    # which joined UUIDs pass at roughly 72 ids
    test 'the key stays well under the indexed column limit for any number of contents' do
      assert_operator(key_for(Array.new(20_000) { SecureRandom.uuid }).bytesize, :<, 2704)
    end

    # the rename path resolves its contents inside the job and enqueues without any
    test 'an empty content list yields a stable key' do
      assert_equal(key_for(nil), key_for([]))
    end

    # every caller enqueues update_things_search beside this one and nothing that invalidates —
    # ClassificationAlias#invalidate_things_cache hangs off after_update. The payload of a linking
    # content is cached under its own timestamps, which a classification change never moves, so
    # without the invalidation the re-export ships exactly what the receiver already has.
    test 'the linking contents are invalidated before the re-export goes out' do
      image = create_content('Bild', { name: 'Destroy Job Image' })
      article = create_content('Artikel', { name: 'Destroy Job Article', image: [image.id] })
      cache_valid_since = DataCycleCore::Thing.find(article.id).cache_valid_since
      seen = nil

      DataCycleCore::RelatedWebhooksJob.stub(:perform_later, ->(*) {}) do
        DataCycleCore::Webhook::Update.stub(:execute_all, ->(*, **) { seen = DataCycleCore::Thing.find(article.id).cache_valid_since }) do
          DataCycleCore.stub(:webhooks, ['Destroy Job ES']) do
            DataCycleCore::CacheInvalidationDestroyJob.perform_now('DataCycleCore::ClassificationAlias', ALIAS_ID, 'execute_things_webhooks_destroy', [image.id])
          end
        end
      end

      assert_operator seen, :>, cache_valid_since
    end
  end
end
