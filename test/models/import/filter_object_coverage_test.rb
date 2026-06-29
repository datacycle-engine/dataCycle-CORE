# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Import
    # Coverage for Import::FilterObject: the query guard/all/reduce branches, the
    # except rebuild and the Mongo filter-hash builders (deleted/archived/updated/
    # deleted_since incl. the blank vs. present locale variants). The Mongo
    # collection is a lightweight double, so no Mongo connection is needed.
    class FilterObjectCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      Subject = DataCycleCore::Import::FilterObject

      def mongo_double
        obj = Object.new
        obj.define_singleton_method(:all) { 'ALL' }
        obj.define_singleton_method(:where) { |*_args| self }
        obj
      end

      test 'query raises when no mongo item is set' do
        assert_raises(RuntimeError) { Subject.new(nil, nil, nil, binding).query }
      end

      test 'query returns all when there are no filters' do
        assert_equal('ALL', Subject.new(nil, nil, mongo_double, binding).query)
      end

      test 'query applies each evaluated filter to the collection' do
        item = mongo_double

        assert_same(item, Subject.new(nil, 'de', item, binding).query)
      end

      test 'except removes a filter and returns a new instance' do
        result = Subject.new(nil, 'de', mongo_double, binding).except(:with_locale)

        assert_kind_of(Subject, result)
      end

      test 'with_deleted_filter and with_archived_filter build existence $or hashes' do
        fo = Subject.new(nil, 'de', mongo_double, binding)

        assert(fo.send(:with_deleted_filter).key?('$or'))
        assert(fo.send(:with_archived_filter).key?('$or'))
      end

      test 'with_updated_since_filter differs for blank and present locale' do
        assert(Subject.new(nil, nil, mongo_double, binding).send(:with_updated_since_filter, 123).key?('updated_at'))
        assert(Subject.new(nil, 'de', mongo_double, binding).send(:with_updated_since_filter, 123).key?('$or'))
      end

      test 'with_deleted_since_filter builds an $or hash' do
        assert(Subject.new(nil, 'de', mongo_double, binding).send(:with_deleted_since_filter, 123).key?('$or'))
      end
    end
  end
end
