# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Fifth wave of the per-file Models >=90% floor push: the DownloadFromData mongo helper
  # mixin and the ImportObject / DownloadObject query helpers. GenericObject#initialize
  # runs create_mongo_indexes!, so the objects are `allocate`d and their ivars set directly;
  # Collection2.with / Mongo::Client are stubbed so no real Mongo connection is opened.
  class UnderNinetyBatchICoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    # --- Generic::Common::Extensions::DownloadFromData -------------------------
    def download_from_data_host
      Class.new {
        include DataCycleCore::Generic::Common::Extensions::DownloadFromData

        def create_aggregate_pipeline(**)
          [{ '$match' => {} }]
        end
      }.new
    end

    def stub_collection2_with(rows, &)
      collection = Object.new
      collection.define_singleton_method(:aggregate) { |*| rows }
      mongo = Object.new
      mongo.define_singleton_method(:collection) { collection }
      with_stub = ->(_read_type, &block) { block.call(mongo) }
      DataCycleCore::Generic::Collection2.stub(:with, with_stub, &)
    end

    test 'DownloadFromData#load_data_from_mongo aggregates over the read-type collection' do
      host = download_from_data_host

      stub_collection2_with([]) do
        result = host.load_data_from_mongo(options: { download: { read_type: 'things', name: 'n' } }, locale: :de, source_filter: {})

        assert_equal [], result
      end

      assert_raises(ArgumentError) do
        host.load_data_from_mongo(options: { download: { name: 'n' } }, locale: :de, source_filter: {})
      end
    end

    test 'DownloadFromData#load_ids_from_mongo handles the transformation and plain-id branches' do
      host = download_from_data_host

      stub_collection2_with([]) do
        assert_equal [], host.load_ids_from_mongo(options: { download: { read_type: 'things', name: 'n' } }, locale: :de, source_filter: {})
      end

      stub_collection2_with([{ 'id' => 'abc' }]) do
        result = host.load_ids_from_mongo(options: { download: { read_type: 'things', name: 'n', data_id_transformation: 'md5' } }, locale: :de, source_filter: {})

        assert_kind_of Array, result
      end
    end

    test 'DownloadFromData#data_name reads the name key' do
      assert_equal 'x', download_from_data_host.data_name({ 'name' => 'x' })
    end

    # --- Generic::ImportObject -------------------------------------------------
    test 'ImportObject concept lookups and source_steps_successful?' do
      import_object = DataCycleCore::Generic::ImportObject.allocate
      import_object.instance_variable_set(:@concepts_cache, {})

      assert_kind_of Array, import_object.concepts_by_path(['Tags > Tag 3'])
      assert_nothing_raised { import_object.concept_by_path('Tags > Tag 3') }

      external_source = Object.new
      external_source.define_singleton_method(:source_steps_successful?) { |_name, _phase| true }
      import_object.instance_variable_set(:@external_source, external_source)
      import_object.instance_variable_set(:@source_name, 'poi')

      assert_predicate import_object, :source_steps_successful?
    end

    # --- Generic::DownloadObject -----------------------------------------------
    test 'DownloadObject item_cache?, read_type and read_type_collection' do
      download_object = DataCycleCore::Generic::DownloadObject.allocate

      assert_not download_object.item_cache?

      download_object.instance_variable_set(:@options, { download: { read_type: 'things' } })

      assert_kind_of Mongoid::PersistenceContext, download_object.read_type

      Mongo::Client.stub(:new, :client) do
        assert_equal :client, download_object.read_type_collection
      end
    end
  end
end
