# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ConceptSchemeUnlinkJobTest < DataCycleCore::TestCases::ActiveSupportTestCase
    CS_ID = '11111111-1111-1111-1111-111111111111'
    COLLECTION_ID = '22222222-2222-2222-2222-222222222222'
    USER_ID = '33333333-3333-3333-3333-333333333333'

    def collection_double(thing)
      things = Object.new
      things.define_singleton_method(:size) { thing.nil? ? 0 : 1 }
      things.define_singleton_method(:find_each) { thing.nil? ? [].each : [thing].each }
      reordered = Object.new
      reordered.define_singleton_method(:reorder) { |_| things }
      collection = Object.new
      collection.define_singleton_method(:things) { reordered }
      collection.define_singleton_method(:name) { 'Collection' }
      collection
    end

    def run_perform(thing:, &)
      cs = Object.new
      cs.define_singleton_method(:name) { 'Concept Scheme' }
      user = Object.new

      job = DataCycleCore::ConceptSchemeUnlinkJob.new(CS_ID, COLLECTION_ID, USER_ID)
      job.define_singleton_method(:concept_scheme_ccc_count) { |*_args| 3 }

      broadcasts = []
      ActionCable.server.stub(:broadcast, ->(name, data) { broadcasts << [name, data] }) do
        DataCycleCore::Collection.stub(:find, collection_double(thing)) do
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

    test 'broadcasts progress and a finished result for a valid run' do
      thing = Object.new
      thing.define_singleton_method(:remove_concepts_by_scheme) do |concept_scheme:, current_user:|
        _ = [concept_scheme, current_user]
        true
      end

      broadcasts = run_perform(thing:)

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

    test 'exposes reference id, type and priority' do
      job = DataCycleCore::ConceptSchemeUnlinkJob.new(CS_ID, COLLECTION_ID, USER_ID)

      assert_equal CS_ID, job.delayed_reference_id
      assert_equal "ConceptSchemeUnlinkJob##{COLLECTION_ID}", job.delayed_reference_type
      assert_equal DataCycleCore::ConceptSchemeUnlinkJob::PRIORITY, job.priority
    end

    test 'check_for_existing_jobs aborts when an equivalent job exists' do
      job = DataCycleCore::ConceptSchemeUnlinkJob.new(CS_ID, COLLECTION_ID, USER_ID)

      Delayed::Job.stub(:exists?, true) do
        assert_throws(:abort) { job.send(:check_for_existing_jobs) }
      end

      Delayed::Job.stub(:exists?, false) do
        assert_nil job.send(:check_for_existing_jobs)
      end
    end
  end
end
