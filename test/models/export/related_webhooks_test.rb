# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Export
    # Coverage for the re-export of the contents linking a changed content: the
    # Export::RelatedWebhooks service, the job resolving the links off the request and the
    # DataHash callbacks triggering it.
    class RelatedWebhooksTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
        @image = create_content('Bild', { name: 'Related Webhooks Image' })
        @article = create_content('Artikel', { name: 'Related Webhooks Article', image: [@image.id] })
        @offer = create_content('Pauschalangebot', { name: 'Related Webhooks Offer', image: [@image.id] })
        @reference = create_content('Vererbte Sprachen', { name: 'Related Webhooks Reference', plain_reference: [@article.id] })

        @block_image = create_content('Bild', { name: 'Related Webhooks Block Image' })
        @structured = create_content('Strukturierter Artikel', { name: 'Related Webhooks Structured', content_block: [{ name: 'Related Webhooks Block', image: [@block_image.id] }] })

        @endpoint = DataCycleCore::StoredFilter.new(name: 'Related Webhooks Endpoint', user_id: @admin.id)
          .parameters_from_hash([{ with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Artikel'] } }])
        @endpoint.save!

        @external_system = DataCycleCore::ExternalSystem.create!(
          name: 'Related Webhooks ES',
          config: {
            'export_config' => {
              'endpoint' => 'DataCycleCore::Export::Generic::Endpoint',
              'filter' => { 'endpoints' => [@endpoint.id] },
              'update' => { 'strategy' => 'DataCycleCore::Export::Generic::Update' }
            }
          }
        )

        @template_system = DataCycleCore::ExternalSystem.create!(
          name: 'Related Webhooks Template ES',
          config: {
            'export_config' => {
              'endpoint' => 'DataCycleCore::Export::Generic::Endpoint',
              'filter' => { 'template_names' => ['Artikel'] },
              'update' => { 'strategy' => 'DataCycleCore::Export::Generic::Update' }
            }
          }
        )
      end

      # the contents an update webhook was triggered for, each with the system it was restricted to
      def triggered(related, content: nil, system_names: nil, invalidate: true, webhooks: [@external_system.name])
        calls = []
        sources = DataCycleCore::Thing.where(id: content.id) if content

        DataCycleCore.stub(:webhooks, webhooks) do
          DataCycleCore::Webhook::Update.stub(:execute_all, ->(target, **kwargs) { calls << [target.id, kwargs[:external_system_id]] }) do
            DataCycleCore::Export::RelatedWebhooks.new(related:, sources:, system_names:, invalidate:).call
          end
        end

        calls
      end

      def triggered_ids(...)
        triggered(...).map(&:first)
      end

      # the receiver each re-exported content is marked pre-filtered for, which is what
      # DataCycleCore::Export::Generic::Filter.filter_endpoints reads
      def filter_marks(webhooks:)
        marks = []

        DataCycleCore.stub(:webhooks, webhooks) do
          DataCycleCore::Webhook::Update.stub(:execute_all, ->(target, **) { marks << target.webhook_filter_checked_for }) do
            DataCycleCore::Export::RelatedWebhooks.new(related: @image.related_contents, invalidate: false).call
          end
        end

        marks
      end

      test 'only the linking contents an endpoint contains are re-exported' do
        assert_equal [@article.id, @offer.id].to_set, @image.related_contents.pluck(:id).to_set
        assert_equal [[@article.id, @external_system.id]], triggered(@image.related_contents)
      end

      test 'a system filtering by something other than endpoints keeps the full set' do
        assert_equal [@article.id, @offer.id].to_set, triggered_ids(@image.related_contents, webhooks: [@template_system.name]).to_set
      end

      # #candidates answered the endpoint filter for the whole relation in one query, so
      # Filter.filter_endpoints must not be put to each content again from inside this job
      test 'a fan-out narrowed by endpoints marks its contents checked for that receiver' do
        assert_equal [@external_system.id], filter_marks(webhooks: [@external_system.name])
      end

      test 'a fan-out narrowed by nothing leaves the filter to run per content' do
        assert_equal [nil, nil], filter_marks(webhooks: [@template_system.name])
      end

      # the candidates stay a relation, so several endpoints have to combine into one query
      test 'a content contained by any of several endpoints is re-exported' do
        offer_endpoint = DataCycleCore::StoredFilter.new(name: 'Related Webhooks Offer Endpoint', user_id: @admin.id)
          .parameters_from_hash([{ with_classification_aliases_and_treename: { treeLabel: 'Inhaltstypen', aliases: ['Pauschalangebot'] } }])
        offer_endpoint.save!

        config = @external_system.config
        @external_system.update!(config: config.deep_merge('export_config' => { 'filter' => { 'endpoints' => [@endpoint.id, offer_endpoint.id] } }))
        @external_system.reload

        assert_equal [@article.id, @offer.id].to_set, triggered_ids(@image.related_contents).to_set
      ensure
        @external_system.update!(config:)
        @external_system.reload
      end

      # dc:sync:trigger_webhooks names one receiver, and the re-export it sets off has to stay on it
      test 'a run restricted to one receiver does not fan out to the others' do
        assert_equal [@external_system.id, @template_system.id].to_set, triggered(@image.related_contents, webhooks: both_systems).to_set(&:last)
        assert_equal [[@article.id, @external_system.id]], triggered(@image.related_contents, system_names: [@external_system.name], webhooks: both_systems)
      end

      test 'the job carries only the receivers the triggering run was restricted to' do
        args = enqueued_args(webhooks: both_systems) do |image|
          image.allowed_webhooks = [@external_system.name]
          image.execute_update_webhooks
        end

        assert_equal [@image.id, nil, [@external_system.name], false], args
      end

      # an import sets webhook_source so the imported content is not pushed back to the system it
      # came from, and the re-export of the contents linking it carries nothing but that change
      test 'the job does not carry the system an import came from' do
        args = enqueued_args(webhooks: both_systems) do |image|
          image.webhook_source = @external_system.name
          image.execute_update_webhooks
        end

        assert_equal [@image.id, nil, [@template_system.name], false], args
      end

      test 'the job does not carry a receiver the change prevents webhooks for' do
        args = enqueued_args(webhooks: both_systems) do |image|
          image.prevent_webhooks = [@external_system.name]
          image.execute_update_webhooks
        end

        assert_equal [@image.id, nil, [@template_system.name], false], args
      end

      test 'a change with no receiver left enqueues no job' do
        args = enqueued_args do |image|
          image.webhook_source = @external_system.name
          image.execute_update_webhooks
        end

        assert_nil args
      end

      test 'the links the job follows are transitive' do
        assert_equal [@article.id, @offer.id, @reference.id].to_set, @image.depending_contents.pluck(:id).to_set
        assert_equal [@article.id, @offer.id, @reference.id].to_set, triggered_ids(@image.depending_contents, webhooks: [@template_system.name]).to_set
      end

      # re-exporting further than the invalidation reaches would ship the payload already cached, so
      # the two read the same walk rather than two that happen to agree
      test 'the set re-exported is the set invalidated, without the embedded contents' do
        invalidated = @block_image.with_cached_related_contents.where.not(id: @block_image.id)

        assert_equal [@structured.content_block.first.id, @structured.id].to_set, invalidated.pluck(:id).to_set
        assert_equal [@structured.id], @block_image.related_webhook_contents.pluck(:id)
      end

      test 'the walk stops where the cache invalidation does' do
        DataCycleCore.stub(:cache_invalidation_depth, 1) do
          assert_equal [@article.id, @offer.id].to_set, @image.related_webhook_contents.pluck(:id).to_set
        end

        DataCycleCore.stub(:cache_invalidation_depth, 2) do
          assert_equal [@article.id, @offer.id, @reference.id].to_set, @image.related_webhook_contents.pluck(:id).to_set
        end
      end

      test 'a content is invalidated before it is re-exported' do
        cache_valid_since = DataCycleCore::Thing.find(@article.id).cache_valid_since

        triggered(@image.related_contents, content: @image)

        assert_operator DataCycleCore::Thing.find(@article.id).cache_valid_since, :>, cache_valid_since
      end

      # the article is nested in the reference's payload under a cache key of its own, so a content
      # between the change and an endpoint content has to be invalidated even though the endpoint
      # never contains it
      test 'a content on the way to a re-exported one is invalidated too' do
        cache_valid_since = DataCycleCore::Thing.find(@reference.id).cache_valid_since

        assert_equal [[@article.id, @external_system.id]], triggered(@image.depending_contents, content: @image)

        assert_operator DataCycleCore::Thing.find(@reference.id).cache_valid_since, :>, cache_valid_since
      end

      # an embedded content drops out of depending_contents, and the payload of the content
      # embedding it renders it from a cache key of its own: invalidating only what is re-exported
      # ships that fragment unchanged
      test 'an embedded content between the change and a re-exported one is invalidated too' do
        block = @structured.content_block.first
        cache_valid_since = DataCycleCore::Thing.find(block.id).cache_valid_since

        assert_equal [@structured.id], @block_image.depending_contents.pluck(:id)

        triggered(@block_image.depending_contents, content: @block_image, webhooks: [@template_system.name])

        assert_operator DataCycleCore::Thing.find(block.id).cache_valid_since, :>, cache_valid_since
      end

      # the job carries the invalidation of the save that triggered it, so it runs whether or not
      # anything is left to re-export
      test 'nothing is triggered without a system to send it to, and the cache is invalidated anyway' do
        cache_valid_since = DataCycleCore::Thing.find(@article.id).cache_valid_since

        assert_empty triggered(@image.related_contents, content: @image, webhooks: [])
        assert_operator DataCycleCore::Thing.find(@article.id).cache_valid_since, :>, cache_valid_since
      end

      # a backfill or a classification rename replaces no invalidation by enqueueing this, so the
      # job must run none: it would race the one those paths already have, and pay for the walk on
      # every content the endpoints do not contain
      test 'a job carrying no invalidation leaves the cache alone' do
        cache_valid_since = DataCycleCore::Thing.find(@article.id).cache_valid_since

        assert_equal [[@article.id, @external_system.id]], triggered(@image.related_contents, content: @image, invalidate: false)
        assert_equal cache_valid_since, DataCycleCore::Thing.find(@article.id).cache_valid_since
      end

      test 'the job resolves the contents linking the changed one' do
        ids = performed_ids { DataCycleCore::RelatedWebhooksJob.perform_now(@image.id) }

        assert_equal [@article.id], ids
      end

      test 'the job falls back to the ids captured before a destroy' do
        ids = performed_ids { DataCycleCore::RelatedWebhooksJob.perform_now(SecureRandom.uuid, [@article.id, @offer.id]) }

        assert_equal [@article.id], ids
      end

      test 'the job is a no-op for a content that no longer exists' do
        assert_empty(performed_ids { DataCycleCore::RelatedWebhooksJob.perform_now(SecureRandom.uuid) })
      end

      test 'a change enqueues the job' do
        args = enqueued_args { |image| image.set_data_hash(data_hash: { name: 'Related Webhooks Image changed' }) }

        assert_equal [@image.id, nil, [@external_system.name], true], args
      end

      # the fan-out lives in execute_update_webhooks, so the single-content callers that never go
      # through set_data_hash (a merge, dc:sync:trigger_webhooks) inherit it. The bulk callers go
      # through .fan_out, which coalesces instead — see the batch coverage below
      test 'every caller of the update webhooks fans out' do
        args = enqueued_args(&:execute_update_webhooks)

        assert_equal [@image.id, nil, [@external_system.name], false], args
      end

      # the fan-out job invalidates the same set itself, and Content.invalidate_all skips rows
      # another run holds: two jobs on two queues cannot be ordered against each other
      test 'a change enqueues the fan-out in place of the cache invalidation job' do
        jobs = enqueued_cache_jobs { |image| image.set_data_hash(data_hash: { name: 'Related Webhooks Image invalidated' }) }

        assert_equal [DataCycleCore::RelatedWebhooksJob], jobs
      end

      # the fan-out invalidated unconditionally once, which made this option a no-op: the save stood
      # down from CacheInvalidationJob and the job it stood down for invalidated in its place
      test 'a change opting out of the related cache invalidation hands the fan-out no invalidation' do
        args = enqueued_args { |image| image.set_data_hash(data_hash: { name: 'Related Webhooks Image opted out' }, invalidate_related_cache: false) }

        assert_equal [@image.id, nil, [@external_system.name], false], args
      end

      test 'a change opting out of the related cache invalidation enqueues no cache invalidation job' do
        jobs = enqueued_cache_jobs { |image| image.set_data_hash(data_hash: { name: 'Related Webhooks Image opted out twice' }, invalidate_related_cache: false) }

        assert_equal [DataCycleCore::RelatedWebhooksJob], jobs
      end

      # Both variants, and not only the one carrying an invalidation: test/dummy/config/queue.yml
      # leaves the webhook queue without a worker, and a fan-out resolving links there would hold a
      # thread the queue keeps for HTTP pushes to the receiver.
      test 'the fan-out job runs on the cache invalidation queue whatever work it is doing' do
        assert_equal DataCycleCore::CacheInvalidationJob.queue_name, DataCycleCore::RelatedWebhooksJob.new(@image.id, nil, nil, true).queue_name
        assert_equal DataCycleCore::CacheInvalidationJob.queue_name, DataCycleCore::RelatedWebhooksJob.new(@image.id, nil, nil, false).queue_name
        assert_not_equal DataCycleCore::WebhookJob.queue_name, DataCycleCore::RelatedWebhooksJob.new(@image.id, nil, nil, false).queue_name
      end

      test 'a change with nothing to fan out to still enqueues the cache invalidation job' do
        jobs = enqueued_cache_jobs(webhooks: []) { |image| image.set_data_hash(data_hash: { name: 'Related Webhooks Image uninvalidated' }) }

        assert_equal [DataCycleCore::CacheInvalidationJob], jobs
      end

      # the fan-out stands down for a change no payload renders, and the invalidation must not
      test 'a timeseries-only change enqueues the cache invalidation job' do
        series = create_content('Timeseries', { name: 'Related Webhooks Invalidated Series' })
        create_content('Vererbte Sprachen', { name: 'Related Webhooks Series Reference', plain_reference: [series.id] })

        jobs = enqueued_cache_jobs(content: series) { |s| s.set_data_hash(data_hash: { series: [{ 'timestamp' => Time.zone.now, 'value' => 1 }] }) }

        assert_equal [DataCycleCore::CacheInvalidationJob], jobs
      end

      test 'an embedded content enqueues no job' do
        args = enqueued_args do |image|
          image.content_type = 'embedded'
          image.execute_update_webhooks
        end

        assert_nil args
      end

      test 'a change that prevents webhooks enqueues no job' do
        args = enqueued_args do |image|
          image.prevent_webhooks = true
          image.set_data_hash(data_hash: { name: 'Related Webhooks Image prevented' })
        end

        assert_nil args
      end

      test 'a save that changes nothing enqueues no job' do
        args = enqueued_args { |image| image.set_data_hash(data_hash: { name: image.name }) }

        assert_nil args
      end

      # a timeseries value renders into no payload, so it reaches neither this content's receivers
      # nor the contents linking it
      test 'a timeseries-only change triggers neither webhook nor fan-out' do
        series = DataCycleCore::Thing.find(create_content('Timeseries', { name: 'Related Webhooks Series' }).id)
        calls = []

        DataCycleCore::RelatedWebhooksJob.stub(:perform_later, ->(*a) { calls << [:job, *a] }) do
          DataCycleCore::Webhook::Update.stub(:execute_all, ->(*, **) { calls << :webhook }) do
            DataCycleCore.stub(:webhooks, [@external_system.name]) do
              series.set_data_hash(data_hash: { series: [{ 'timestamp' => Time.zone.now, 'value' => 1 }] })
            end
          end
        end

        assert_equal ['series'], series.previous_datahash_changes.keys
        assert_empty calls
      end

      # Three properties, three reasons, one list: Content::Content#non_payload_property_names
      # holds them and says why no receiver hears about a change to any of the three.
      test 'a change to non-payload properties alone triggers neither webhook nor fan-out' do
        article = DataCycleCore::Thing.find(create_content('Artikel', { name: 'Related Webhooks Mongo Article', image: [@image.id], dc_mongo_key: 'doc-1', dc_ext_key_priority: 3, dummy: 'do_not_show' }).id)
        calls = []

        DataCycleCore::RelatedWebhooksJob.stub(:perform_later, ->(*a) { calls << [:job, *a] }) do
          DataCycleCore::Webhook::Update.stub(:execute_all, ->(*, **) { calls << :webhook }) do
            DataCycleCore.stub(:webhooks, [@external_system.name]) do
              article.set_data_hash(data_hash: { dc_mongo_key: 'doc-2', dc_ext_key_priority: 1, dummy: 'do_not_show_either' })
            end
          end
        end

        assert_equal ['dc_mongo_key', 'dc_ext_key_priority', 'dummy'].sort, article.previous_datahash_changes.keys.sort
        assert_empty calls
      end

      # perform_later answers false for an enqueue abort_if_queued dropped, and the job already queued
      # carries the invalidation — the flag is part of its concurrency key. Guarding on blank? rather
      # than nil? would invalidate a second time, from a job holding the same rows from another queue.
      test 'a fan-out enqueue dropped as a duplicate keeps the cache invalidation stood down' do
        jobs = enqueued_cache_jobs(fan_out: false) { |image| image.set_data_hash(data_hash: { name: 'Related Webhooks Image dropped fan-out' }) }

        assert_equal [DataCycleCore::RelatedWebhooksJob], jobs
      end

      # a scope-style class method on Thing would leave current_scope set for the whole call, so every
      # Thing query the export filters make below would be narrowed to the set being fanned out
      test 'the bulk fan-out leaves no scope behind for the export filters' do
        seen = nil

        DataCycleCore::RelatedWebhooksJob.stub(:perform_later, ->(*) {}) do
          DataCycleCore::Webhook::Update.stub(:execute_all, ->(*, **) { seen = DataCycleCore::Thing.where(id: @article.id).count }) do
            DataCycleCore.stub(:webhooks, [@external_system.name]) do
              DataCycleCore::Content::RelatedWebhooks.fan_out(DataCycleCore::Thing.where(id: @image.id))
            end
          end
        end

        assert_equal 1, seen
      end

      test 'the invalidation a fan-out carries is part of what makes it unique' do
        args = [@image.id, nil, [@external_system.name]]

        assert_not_equal DataCycleCore::RelatedWebhooksJob.new(*args, true).concurrency_key,
                         DataCycleCore::RelatedWebhooksJob.new(*args, false).concurrency_key
      end

      test 'a destroy enqueues the job with the linking contents captured beforehand' do
        image = create_content('Bild', { name: 'Related Webhooks Destroyed Image' })
        article = create_content('Artikel', { name: 'Related Webhooks Destroyed Article', image: [image.id] })

        args = nil
        DataCycleCore::RelatedWebhooksJob.stub(:perform_later, ->(*a) { args = a }) do
          DataCycleCore.stub(:webhooks, [@external_system.name]) do
            image.destroy_content
          end
        end

        assert_equal [image.id, [article.id], [@external_system.name], false], args
      end

      # The point of coalescing: a batch member is re-exported by .fan_out's own per-content
      # delivery, so the union walk must not hand it a second delivery as another member's linker.
      # @article is the only content @endpoint contains, so it stands in for the whole overlap.
      test 'a content changed alongside another is not re-exported as its linker' do
        assert_equal([@article.id], performed_ids { perform_fan_out(@image.id) })
        assert_empty(performed_ids { perform_fan_out([@image.id, @article.id]) })
      end

      test 'the bulk fan-out coalesces a batch into one job carrying every id' do
        args = fan_out_args(DataCycleCore::Thing.where(id: [@image.id, @article.id]))

        assert_equal 1, args.size
        assert_equal [[@image.id, @article.id].sort, nil, [@external_system.name], false],
                     [args.first.first.sort, *args.first.drop(1)]
      end

      # the deliveries the batch members get in their own right, which #execute_update_webhooks
      # paired with the fan-out before .fan_out took the pairing over
      test 'the bulk fan-out re-exports the changed contents themselves' do
        ids = performed_ids do
          DataCycleCore::RelatedWebhooksJob.stub(:perform_later, ->(*) {}) do
            DataCycleCore::Content::RelatedWebhooks.fan_out(DataCycleCore::Thing.where(id: @article.id))
          end
        end

        assert_equal [@article.id], ids
      end

      # find_in_batches yields no ORDER BY, so the same batch can arrive in either order and must
      # not look like two jobs
      test 'the coalesced fan-out is keyed on the set rather than the order of its ids' do
        assert_equal fan_out_key([@image.id, @article.id]), fan_out_key([@article.id, @image.id])
        assert_not_equal fan_out_key([@image.id]), fan_out_key([@image.id, @article.id])
      end

      # a save's own content plus the shared embedded it changed travel as one list, and the export
      # invalidates from all of them in one statement (Export::RelatedWebhooks#call)
      test 'a list may carry an invalidation' do
        assert_enqueued_with(job: DataCycleCore::RelatedWebhooksJob, args: [[@image.id, @article.id], nil, [@external_system.name], true]) do
          DataCycleCore::Content::RelatedWebhooks.enqueue([@image.id, @article.id], [@external_system.name], invalidate: true)
        end
      end

      # SolidQueue claims ready executions in priority ASC, job_id ASC order (Execution.ordered), so
      # the lower number runs first. A fan-out carrying an invalidation stands in for the
      # CacheInvalidationJob its caller stood down, so it must not wait behind the jobs sharing its
      # queue - until it runs, the contents it re-exports hold the caches its invalidation is there
      # to lift. Carrying none it replaces nothing, .fan_out having invalidated up front, and has no
      # claim ahead of the invalidations a save is waiting on. There is no third assertion against the
      # content_maintenance tier: a claim reads one queue's ready set, so priorities set on two
      # different queues never meet.
      test 'only the fan-out standing in for a cache invalidation outranks one' do
        assert_operator fan_out_priority(invalidate: true), :<, DataCycleCore::CacheInvalidationJob.priority
        assert_equal DataCycleCore::CacheInvalidationJob.priority, fan_out_priority(invalidate: false)
      end

      # the reason args[0] is hashed: solid_queue_jobs.concurrency_key is btree-indexed, and an index
      # row over 2704 bytes raises PG::ProgramLimitExceeded on enqueue — roughly 72 of these UUIDs
      test 'a full batch of ids still fits the concurrency key index' do
        ids = Array.new(DataCycleCore::Content::RelatedWebhooks::FAN_OUT_BATCH_SIZE) { SecureRandom.uuid }

        assert_operator fan_out_key(ids).bytesize, :<, 2704
      end

      private

      def both_systems
        [@external_system.name, @template_system.name]
      end

      # the arguments of every job one bulk fan-out enqueued
      def fan_out_args(scope)
        args = []

        DataCycleCore::RelatedWebhooksJob.stub(:perform_later, ->(*a) { args << a }) do
          DataCycleCore::Webhook::Update.stub(:execute_all, ->(*, **) {}) do
            DataCycleCore.stub(:webhooks, [@external_system.name]) do
              DataCycleCore::Content::RelatedWebhooks.fan_out(scope)
            end
          end
        end

        args
      end

      def fan_out_key(ids)
        DataCycleCore::RelatedWebhooksJob.new(ids, nil, [@external_system.name], false).concurrency_key
      end

      def fan_out_priority(invalidate:)
        DataCycleCore::RelatedWebhooksJob.new(@image.id, nil, [@external_system.name], invalidate).priority
      end

      # runs the fan-out job the way .fan_out enqueues it: no invalidation to carry
      def perform_fan_out(ids)
        DataCycleCore::RelatedWebhooksJob.perform_now(ids, nil, [@external_system.name], false)
      end

      # the contents the job triggered an update webhook for
      def performed_ids(&)
        ids = []

        DataCycleCore.stub(:webhooks, [@external_system.name]) do
          DataCycleCore::Webhook::Update.stub(:execute_all, ->(content, **) { ids << content.id }, &)
        end

        ids
      end

      # the job classes a change enqueued for the cache of the contents linking it
      # @param fan_out [Object] what RelatedWebhooksJob.perform_later answers — false for an enqueue
      #   abort_if_queued dropped
      def enqueued_cache_jobs(content: @image, webhooks: [@external_system.name], fan_out: true)
        jobs = []

        fan_out_stub = lambda do |*|
          jobs << DataCycleCore::RelatedWebhooksJob
          fan_out
        end

        DataCycleCore::RelatedWebhooksJob.stub(:perform_later, fan_out_stub) do
          DataCycleCore::CacheInvalidationJob.stub(:perform_later, ->(*) { jobs << DataCycleCore::CacheInvalidationJob }) do
            DataCycleCore::Webhook::Update.stub(:execute_all, ->(*, **) {}) do
              DataCycleCore.stub(:webhooks, webhooks) { yield DataCycleCore::Thing.find(content.id) }
            end
          end
        end

        jobs
      end

      # the arguments the changed content enqueued the job with, nil if it enqueued none
      def enqueued_args(webhooks: [@external_system.name])
        args = nil

        DataCycleCore::RelatedWebhooksJob.stub(:perform_later, ->(*a) { args = a }) do
          DataCycleCore::Webhook::Update.stub(:execute_all, ->(*, **) {}) do
            DataCycleCore.stub(:webhooks, webhooks) do
              yield DataCycleCore::Thing.find(@image.id)
            end
          end
        end

        args
      end
    end
  end
end
