# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class RelationFilterTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @things_count = DataCycleCore::Thing.count
      image = create_content('Bild', { name: 'Test Bild Linked' })
      author1 = create_content('Organization', { name: 'Author 1' })
      author2 = create_content('Organization', { name: 'Author 2' })
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 1', author: [author1.id] })
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 2', author: [author2.id] })
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 3', author: [author1.id], image: [image.id] })
      create_content('Artikel', { name: 'HEADLINE - NO TAGS 4', image: [image.id] })
    end

    test 'filter contents based on author relation exists' do
      items = DataCycleCore::Filter::Search.new(locale: :de).exists_relation_filter('author')
      assert_equal(3, items.count)
      items = DataCycleCore::Filter::Search.new(locale: :de).exists_relation_filter('author', false)
      assert_equal(3, items.count)
      items = DataCycleCore::Filter::Search.new(locale: :de).exists_relation_filter('author', true)
      assert_equal(2, items.count)
      # DataCycleCore::StoredFilter.apply_filter_parameters calls the method with two strings
      items = DataCycleCore::Filter::Search.new(locale: :de).exists_relation_filter('author', 'author')
      assert_equal(3, items.count)
    end

    test 'filter contents based on author relation not exists' do
      items = DataCycleCore::Filter::Search.new(locale: :de).not_exists_relation_filter('author')
      assert_equal(4, items.count)
      items = DataCycleCore::Filter::Search.new(locale: :de).not_exists_relation_filter('author', false)
      assert_equal(4, items.count)
      items = DataCycleCore::Filter::Search.new(locale: :de).not_exists_relation_filter('author', true)
      assert_equal(5, items.count)
      # DataCycleCore::StoredFilter.apply_filter_parameters calls the method with two strings
      items = DataCycleCore::Filter::Search.new(locale: :de).not_exists_relation_filter('author', 'author')
      assert_equal(4, items.count)
    end
  end
end
