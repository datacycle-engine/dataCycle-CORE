# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Fourth wave of the per-file Models >=90% floor push: the Generic::Common download
  # strategy modules and RunRakeTask. Each forwards to a DownloadFunctions /
  # DownloadDataFromData helper (stubbed so no Mongo is touched); the local proc / id /
  # name builders and load_contents guards run directly.
  class UnderNinetyBatchHCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    DF = DataCycleCore::Generic::Common::DownloadFunctions
    GC = DataCycleCore::Generic::Common

    test 'RunRakeTask.process_content invokes and reenables the task' do
      task = Object.new
      task.define_singleton_method(:invoke) { |*| nil }
      task.define_singleton_method(:reenable) { nil }

      DataCycleCore::RakeTaskService.stub(:load_tasks, nil) do
        Rake::Task.stub(:[], task) do
          assert GC::RunRakeTask.process_content(nil, { import: { rake_task: 'x', rake_args: [] } })
        end
      end
    end

    test 'DownloadContents.download_content forwards id/name procs to DownloadFunctions' do
      ids = []
      names = []

      DF.stub(:download_content, lambda { |**kwargs|
        ids << kwargs[:data_id].call({ 'a' => { 'b' => 'id-1' } })
        names << kwargs[:data_name].call({ 'a' => { 'c' => 'name-1' } })
      }) do
        GC::DownloadContents.download_content(utility_object: nil, options: { download: { id_path: 'a.b', name_path: 'a.c' } })
      end

      assert_equal ['id-1'], ids
      assert_equal ['name-1'], names
    end

    test 'DownloadMarkDeleted download + load_contents validate the source filter' do
      DF.stub(:mark_deleted_from_data, :marked) do
        assert_equal :marked, GC::DownloadMarkDeleted.download_content(utility_object: nil, options: {})
      end

      mongo_item = Object.new
      mongo_item.define_singleton_method(:where) { |filter| [filter] }

      assert_equal [{ 'custom' => 1 }], GC::DownloadMarkDeleted.load_contents(mongo_item, 'de', { 'custom' => 1 })
      assert_raises(RuntimeError) { GC::DownloadMarkDeleted.load_contents(mongo_item, 'de', { 'updated_at' => 1 }) }
      assert_raises(RuntimeError) { GC::DownloadMarkDeleted.load_contents(mongo_item, 'de', {}) }
    end

    test 'DownloadBulkTouchFromData forwards to bulk_touch_items and load_ids_from_mongo' do
      DF.stub(:bulk_touch_items, :touched) do
        assert_equal :touched, GC::DownloadBulkTouchFromData.download_content(utility_object: nil, options: {})
      end

      GC::DownloadDataFromData.stub(:load_ids_from_mongo, :ids) do
        assert_equal :ids, GC::DownloadBulkTouchFromData.load_contents(options: {})
      end
    end

    test 'DownloadBulkMarkDeleted sets full mode and merges the read type' do
      utility_object = Object.new
      mode = nil
      utility_object.define_singleton_method(:mode=) { |value| mode = value }

      DF.stub(:bulk_mark_deleted, :marked) do
        assert_equal :marked, GC::DownloadBulkMarkDeleted.download_content(utility_object:, options: {})
      end
      assert_equal :full, mode

      forwarded = nil
      GC::DownloadDataFromData.stub(:load_ids_from_mongo, ->(**kwargs) { forwarded = kwargs }) do
        GC::DownloadBulkMarkDeleted.load_contents(options: { download: { source_type: 'poi' } })
      end

      assert_equal 'poi', forwarded[:options].dig(:download, :read_type)
    end

    test 'DownloadBulkMarkDeletedFromThingHistories sets full mode and queries histories' do
      utility_object = Object.new
      utility_object.define_singleton_method(:mode=) { |_value| nil }

      DF.stub(:bulk_mark_deleted, :marked) do
        assert_equal :marked, GC::DownloadBulkMarkDeletedFromThingHistories.download_content(utility_object:, options: {})
      end

      download_object = struct_double(external_source: struct_double(id: SecureRandom.uuid))

      assert_kind_of Array, GC::DownloadBulkMarkDeletedFromThingHistories.load_contents(download_object:)
    end

    test 'DownloadConceptSchemesFromConfig builds schemes from the configured tree labels' do
      DF.stub(:download_content, :ok) do
        assert_equal :ok, GC::DownloadConceptSchemesFromConfig.download_content(utility_object: nil, options: {})
      end

      schemes = GC::DownloadConceptSchemesFromConfig.load_concept_schemes_from_config(options: { download: { tree_label: 'Tags' } })

      assert_equal [{ 'id' => 'Tags', 'name' => 'Tags' }], schemes
      assert_equal 'x', GC::DownloadConceptSchemesFromConfig.data_id({ 'id' => 'x' })
      assert_equal 'y', GC::DownloadConceptSchemesFromConfig.data_name({ 'name' => 'y' })
    end
  end
end
