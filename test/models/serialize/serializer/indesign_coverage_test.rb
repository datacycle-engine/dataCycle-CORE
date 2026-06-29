# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Serialize
    module Serializer
      # Coverage for the Indesign serializer. The serialize_* entry points are exercised
      # over content / watch-list / stored-filter doubles; the SerializedData::Content
      # entries are built with their render lambdas left uninvoked, so the wrapping logic
      # (selection, pagination, file naming) is covered without booting the XML renderer.
      class IndesignCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        Subject = DataCycleCore::Serialize::Serializer::Indesign
        ContentCollection = DataCycleCore::Serialize::SerializedData::ContentCollection

        def content_double(title: 'Test', asset_property_names: [])
          content = Object.new
          content.define_singleton_method(:title) { title }
          content.define_singleton_method(:asset_property_names) { asset_property_names }
          content.define_singleton_method(:id) { SecureRandom.uuid }
          content
        end

        def stored_filter_double
          pageable = Object.new
          applied = Object.new
          applied.define_singleton_method(:count) { 0 }
          applied.define_singleton_method(:page) { |_page| pageable }
          pageable.define_singleton_method(:per) { |_per| applied }

          stored_filter = Object.new
          stored_filter.define_singleton_method(:apply) { applied }
          stored_filter.define_singleton_method(:title) { 'My Filter' }
          stored_filter.define_singleton_method(:id) { SecureRandom.uuid }
          stored_filter
        end

        test 'translatable? and mime_type advertise an XML serializer' do
          assert_predicate Subject, :translatable?
          assert_equal 'application/xml', Subject.mime_type
        end

        test 'serializable? requires an available serializer and no asset properties' do
          DataCycleCore::Feature::Serialize.stub(:available_serializer?, true) do
            assert Subject.serializable?(content_double(asset_property_names: []))
            assert_not Subject.serializable?(content_double(asset_property_names: ['image']))
          end
        end

        test 'serialize_thing wraps and serializes the serializable contents' do
          collection = DataCycleCore::Feature::Serialize.stub(:available_serializer?, true) do
            Subject.serialize_thing(content: content_double, language: 'de')
          end

          assert_kind_of ContentCollection, collection
        end

        test 'serialize_watch_list builds a single content entry' do
          collection = Subject.serialize_watch_list(content: content_double(title: 'My Watchlist'), language: 'de')

          assert_kind_of ContentCollection, collection
        end

        test 'serialize_stored_filter paginates and builds a single content entry' do
          collection = Subject.serialize_stored_filter(content: stored_filter_double, language: 'de')

          assert_kind_of ContentCollection, collection
        end
      end
    end
  end
end
