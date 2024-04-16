# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CollectionSlugTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @collection = DataCycleCore::TestPreparations.create_watch_list(name: 'Inhaltssammlung 1')
      @collection2 = DataCycleCore::StoredFilter.create(name: 'Gespeicherte Suche 1')
    end

    test 'collections creates slug' do
      assert_equal 'inhaltssammlung-1', @collection.slug
      assert_equal 'gespeicherte-suche-1', @collection2.slug
    end

    test 'collections update slug only manually' do
      @collection.update(full_path: 'Test')
      assert_equal 'inhaltssammlung-1', @collection.slug

      @collection2.update(name: 'Test')
      assert_equal 'gespeicherte-suche-1', @collection2.slug
    end

    test 'collections increment slug' do
      @collection.update(slug: 'Test')
      @collection2.update(slug: 'Test')

      assert_equal 'test', @collection.slug
      assert_equal 'test-1', @collection2.slug
    end

    test 'multiple watch_list slugs are generated correctly' do
      @collection.update(slug: 'test')
      assert_equal 'test', @collection.slug

      1.upto(10) do |index|
        assert_equal "test-#{index}", DataCycleCore::StoredFilter.create(name: 'Test').slug
      end
    end
  end
end
