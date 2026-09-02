# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptSchemeUnlinkJobTest < DataCycleCore::TestCases::ActiveSupportTestCase
    CS_ID = '11111111-1111-1111-1111-111111111111'
    COLLECTION_ID = '22222222-2222-2222-2222-222222222222'
    USER_ID = '33333333-3333-3333-3333-333333333333'

    def collection_double(thing_list)
      things = Object.new
      things.define_singleton_method(:size) { thing_list.size }
      things.define_singleton_method(:find_each) { thing_list.each }
      reordered = Object.new
      reordered.define_singleton_method(:reorder) { |_| things }
      collection = Object.new
      collection.define_singleton_method(:things) { reordered }
      collection.define_singleton_method(:name) { 'Collection' }
      collection
    end

    def valid_thing_double
      thing = Object.new
      thing.define_singleton_method(:remove_concepts_by_scheme) do |concept_scheme:, current_user:|
        _ = [concept_scheme, current_user]
        true
      end
      thing
    end

    def run_perform(thing: nil, things: [thing].compact, &)
      cs = Object.new
      cs.define_singleton_method(:name) { 'Concept Scheme' }
      user = Object.new

      job = DataCycleCore::ConceptSchemeUnlinkJob.new(CS_ID, COLLECTION_ID, USER_ID)
      job.define_singleton_method(:concept_scheme_ccc_count) { |*_args| 3 }

      broadcasts = []
      ActionCable.server.stub(:broadcast, ->(name, data) { broadcasts << [name, data] }) do
        DataCycleCore::Collection.stub(:find, collection_double(things)) do
          DataCycleCore::ConceptScheme.stub(:find, cs) do
            DataCycleCore::User.stub(:find, user) do
              yield(job) if block_given?
              job.perform(CS_ID, COLLECTION_ID, USER_ID)
            end
          end
        end
      end
      broadcasts
    end

    def state_key
      DataCycleCore::ConceptSchemeUnlinkJob.state_cache_key(CS_ID, COLLECTION_ID)
    end

    test 'broadcasts progress and a finished result for a valid run' do
      broadcasts = run_perform(thing: valid_thing_double)

      assert(broadcasts.any? { |_, d| d[:progress].zero? })
      finished = broadcasts.find { |_, d| d[:finished] }

      assert finished
      assert finished[1][:result].first[:valid]
    end

    test 'reports the error message for an invalid thing' do
      thing = Object.new
      thing.define_singleton_method(:remove_concepts_by_scheme) do |concept_scheme:, current_user:|
        _ = [concept_scheme, current_user]
        false
      end
      errors = Object.new
      errors.define_singleton_method(:full_messages) { ['broken'] }
      thing.define_singleton_method(:errors) { errors }

      broadcasts = run_perform(thing:)

      finished = broadcasts.find { |_, d| d[:finished] }

      assert_not finished[1][:result].first[:valid]
      assert_equal 'broken', finished[1][:result].first[:error]
    end

    test 'broadcasts an error when something raises' do
      job = DataCycleCore::ConceptSchemeUnlinkJob.new(CS_ID, COLLECTION_ID, USER_ID)
      broadcasts = []

      ActionCable.server.stub(:broadcast, ->(name, data) { broadcasts << [name, data] }) do
        DataCycleCore::Collection.stub(:find, ->(_) { raise StandardError, 'kaputt' }) do
          job.perform(CS_ID, COLLECTION_ID, USER_ID)
        end
      end

      assert(broadcasts.any? { |_, d| d[:error] == 'kaputt' })
    end

    test 'mirrors the last broadcast into the cache for a client that reconnects mid-run' do
      broadcasts = run_perform(thing: valid_thing_double)

      assert_equal broadcasts.find { |_, d| d[:finished] }.last, Rails.cache.read(state_key)
    end

    test 'broadcasts progress once per whole percent, not once per thing' do
      things = Array.new(200) { valid_thing_double }

      progress = run_perform(things:).filter_map { |_, d| d[:progress] }

      assert_operator progress.size, :<, things.size
      assert_equal progress.uniq, progress
      assert_equal 100, progress.last
    end

    test 'enqueuing drops the previous run cached state' do
      Rails.cache.write(state_key, { finished: true })

      DataCycleCore::ConceptSchemeUnlinkJob.perform_later(CS_ID, COLLECTION_ID, USER_ID)

      assert_nil Rails.cache.read(state_key)
    end

    test 'a dropped duplicate enqueue leaves the running state alone' do
      Rails.cache.write(state_key, { progress: 42 })
      job = DataCycleCore::ConceptSchemeUnlinkJob.new(CS_ID, COLLECTION_ID, USER_ID)
      SolidQueue::Job.create!(
        queue_name: job.queue_name,
        class_name: job.class.name,
        arguments: job.serialize,
        concurrency_key: job.concurrency_key
      )

      DataCycleCore::ConceptSchemeUnlinkJob.perform_later(CS_ID, COLLECTION_ID, USER_ID)

      assert_equal({ progress: 42 }, Rails.cache.read(state_key))
    end

    test 'exposes its concurrency key and priority' do
      job = DataCycleCore::ConceptSchemeUnlinkJob.new(CS_ID, COLLECTION_ID, USER_ID)

      assert_equal "DataCycleCore::ConceptSchemeUnlinkJob/#{CS_ID}/#{COLLECTION_ID}", job.concurrency_key
      assert_equal 10, job.priority
    end

    test 'link and unlink of the same pair do not exclude each other' do
      assert_not_equal DataCycleCore::ConceptSchemeUnlinkJob.new(CS_ID, COLLECTION_ID, USER_ID).concurrency_key,
                       DataCycleCore::ConceptSchemeLinkJob.new(CS_ID, COLLECTION_ID, USER_ID).concurrency_key
    end

    # by the time the first run finishes there is nothing left to unlink, so the second must be
    # dropped rather than queued behind it — running the same unlink twice is what the delayed_job
    # era prevented with a `throw :abort` on any non-failed job for the reference
    test 'a second unlink of the same pair is dropped, not queued' do
      assert_equal 'discard', DataCycleCore::ConceptSchemeUnlinkJob.concurrency_on_conflict.to_s

      job = DataCycleCore::ConceptSchemeUnlinkJob.new(CS_ID, COLLECTION_ID, USER_ID)
      SolidQueue::Job.create!(
        queue_name: job.queue_name,
        class_name: job.class.name,
        arguments: job.serialize,
        concurrency_key: job.concurrency_key
      )

      assert_not DataCycleCore::ConceptSchemeUnlinkJob.perform_later(CS_ID, COLLECTION_ID, USER_ID)
    end
  end
end
