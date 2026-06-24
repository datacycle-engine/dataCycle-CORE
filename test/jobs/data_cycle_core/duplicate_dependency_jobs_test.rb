# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DuplicateDependencyJobsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    UUID = '00000000-0000-0000-0000-000000000000'

    def thing_double(allowed:, affected:, embedded: false)
      created = []
      thing = Object.new
      thing.define_singleton_method(:id) { UUID }
      thing.define_singleton_method(:embedded?) { embedded }
      thing.define_singleton_method(:duplicate_candidates_allowed?) { allowed }
      thing.define_singleton_method(:affected_by_change?) { |_attrs| affected }
      thing.define_singleton_method(:create_duplicate_candidates) { created << :created }
      thing.define_singleton_method(:created) { created }
      thing
    end

    def relation_double(thing)
      relation = Object.new
      relation.define_singleton_method(:find_each) { |&block| block.call(thing) }
      relation
    end

    test 'check_dependent returns when the feature is disabled' do
      DataCycleCore::Feature::DuplicateCandidate.stub(:enabled?, false) do
        assert_nil DataCycleCore::CheckDependentForDuplicatesJob.perform_now(UUID, {})
      end
    end

    test 'check_dependent returns when there is no dependent attribute hash' do
      DataCycleCore::Feature::DuplicateCandidate.stub(:enabled?, true) do
        DataCycleCore::ContentContent::Link.stub(:id_attribute_hash, {}) do
          assert_nil DataCycleCore::CheckDependentForDuplicatesJob.perform_now(UUID, {})
        end
      end
    end

    test 'check_dependent creates duplicate candidates for affected things' do
      thing = thing_double(allowed: true, affected: true)

      DataCycleCore::Feature::DuplicateCandidate.stub(:enabled?, true) do
        DataCycleCore::ContentContent::Link.stub(:id_attribute_hash, { UUID => ['name'] }) do
          DataCycleCore::Thing.stub(:where, relation_double(thing)) do
            DataCycleCore::CheckDependentForDuplicatesJob.perform_now(UUID, { 'name' => true })
          end
        end
      end

      assert_equal [:created], thing.created
    end

    test 'check_dependent skips things that are not affected' do
      thing = thing_double(allowed: true, affected: false)

      DataCycleCore::Feature::DuplicateCandidate.stub(:enabled?, true) do
        DataCycleCore::ContentContent::Link.stub(:id_attribute_hash, { UUID => ['name'] }) do
          DataCycleCore::Thing.stub(:where, relation_double(thing)) do
            DataCycleCore::CheckDependentForDuplicatesJob.perform_now(UUID, { 'name' => true })
          end
        end
      end

      assert_empty thing.created
    end

    test 'check_dependent exposes its reference id and priority' do
      job = DataCycleCore::CheckDependentForDuplicatesJob.new(UUID, {})

      assert_equal UUID, job.delayed_reference_id
      assert_equal DataCycleCore::CheckDependentForDuplicatesJob::PRIORITY, job.priority
    end

    test 'destroy_dependent returns when the attribute hash is present' do
      assert_nil DataCycleCore::DestroyDependentForDuplicatesJob.perform_now(UUID, { UUID => ['name'] })
    end

    test 'destroy_dependent checks relevant things when the hash is blank' do
      # an empty hash means there are no thing ids to look up, so the relation is empty
      assert_nil DataCycleCore::DestroyDependentForDuplicatesJob.perform_now(UUID, {})
    end
  end
end
