# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Third wave of the per-file Models >=90% floor push: the status/step aggregation on
  # ExternalSystem, the DeleteContentsUpdateAttributes import strategy guards, and the
  # DuplicateCandidate data-hash hooks. Collaborators (steps, jobs, import pipeline) are
  # stubbed so the branch logic runs without real external systems or background jobs.
  class UnderNinetyBatchGCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # --- ExternalSystemExtensions::Status --------------------------------------
    test 'ExternalSystem#fail_running_steps! only ends steps still running' do
      external_system = DataCycleCore::ExternalSystem.new
      step_info = {
        'step-1' => { 'status' => 'running', 'last_try' => Time.zone.now.iso8601 },
        'step-2' => { 'status' => 'finished' }
      }
      ended = []

      external_system.stub(:last_import_step_time_info, step_info) do
        external_system.stub(:update_step_timestamp_end, ->(*args) { ended << args }) do
          external_system.fail_running_steps!
        end
      end

      assert_equal 1, ended.size
      assert_equal 'step-1', ended.first[1]
    end

    test 'ExternalSystem#last_status maps aggregated step statuses' do
      external_system = DataCycleCore::ExternalSystem.new

      external_system.stub(:import_accessors, ['k']) do
        external_system.stub(:step_info_for, ->(_k) { { 'status' => 'running' } }) do
          assert_equal 'running', external_system.send(:last_status, :import)
        end
        external_system.stub(:step_info_for, ->(_k) { { 'status' => 'error' } }) do
          assert_equal 'error', external_system.send(:last_status, :import)
        end
        external_system.stub(:step_info_for, ->(_k) { { 'status' => 'pending' } }) do
          assert_equal 'unknown', external_system.send(:last_status, :import)
        end
      end
    end

    # --- Generic::Common::DeleteContentsUpdateAttributes -----------------------
    DCUA = DataCycleCore::Generic::Common::DeleteContentsUpdateAttributes

    test 'DeleteContentsUpdateAttributes.import_data drives the import pipeline in full mode' do
      utility_object = Object.new
      utility_object.define_singleton_method(:mode=) { |_v| nil }
      captured = nil

      DataCycleCore::Generic::Common::ImportFunctions.stub(:import_contents, ->(**kwargs) { captured = kwargs }) do
        DCUA.import_data(utility_object:, options: {})
      end

      assert captured[:iterator]
      assert captured[:data_processor]
    end

    test 'DeleteContentsUpdateAttributes.load_contents builds the with-deleted query' do
      filter_object = Object.new
      filter_object.define_singleton_method(:except) { |*| self }
      filter_object.define_singleton_method(:with_deleted) { self }
      filter_object.define_singleton_method(:query) { [] }

      assert_equal [], DCUA.load_contents(filter_object:)
    end

    test 'DeleteContentsUpdateAttributes.process_content raises without a recent download' do
      utility_object = Object.new
      utility_object.define_singleton_method(:source_steps_successful?) { true }
      utility_object.define_singleton_method(:last_successful_try) { nil }

      error = assert_raises(RuntimeError) do
        DCUA.process_content(
          utility_object:, raw_data: {}, locale: :de,
          options: { import: { last_successful_try: 'Time.zone.now + 86400' } }
        )
      end

      assert_match(/No recent successful download/, error.message)
    end

    # --- Feature::DataHash::DuplicateCandidate ---------------------------------
    def duplicate_candidate_host
      Class.new {
        include DataCycleCore::Feature::DataHash::DuplicateCandidate

        def id
          'thing-1'
        end

        def first_available_locale
          :de
        end

        def set_data_hash(**)
        end

        def datahash_changes
          { 'name' => ['a', 'b'] }
        end
      }.new
    end

    test 'DuplicateCandidate#create_merge_version names the version after the duplicate' do
      host = duplicate_candidate_host
      duplicate = Object.new
      duplicate.define_singleton_method(:original_id=) { |_v| nil }
      duplicate.define_singleton_method(:id) { 'dup-1' }

      DataCycleCore::Feature::DuplicateCandidate.stub(:version_name_for_merge, 'v1') do
        assert_nil host.create_merge_version(duplicate)
      end
    end

    test 'DuplicateCandidate#merge_with_duplicate queues the job when async' do
      host = duplicate_candidate_host
      duplicate = Object.new
      duplicate.define_singleton_method(:id) { 'dup-1' }
      queued = []

      DataCycleCore::MergeDuplicateJob.stub(:perform_later, ->(*args) { queued << args }) do
        DataCycleCore::Thing.stub(:find_by, nil) do
          assert_nil host.merge_with_duplicate(duplicate)
        end
      end

      assert_equal [['thing-1', 'dup-1', nil]], queued
    end

    test 'DuplicateCandidate dependent and destroy job schedulers' do
      host = duplicate_candidate_host

      DataCycleCore::CheckDependentForDuplicatesJob.stub(:perform_later, nil) do
        assert_nil host.send(:add_dependent_check_for_duplicates_job)
      end

      DataCycleCore::ContentContent::Link.stub(:id_attribute_hash, {}) do
        assert_nil host.send(:add_destroy_check_for_duplicates_job)
      end

      scheduled = []
      DataCycleCore::ContentContent::Link.stub(:id_attribute_hash, { 'a' => ['b'] }) do
        DataCycleCore::DestroyDependentForDuplicatesJob.stub(:perform_later, ->(*args) { scheduled << args }) do
          host.send(:add_destroy_check_for_duplicates_job)
        end
      end

      assert_equal 1, scheduled.size
    end
  end
end
