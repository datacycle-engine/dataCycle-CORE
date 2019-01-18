# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SearchTest < ActiveSupport::TestCase
    def setup
      @things = DataCycleCore::Thing.where(template: false).count
      create_content('Artikel', { name: 'AAA' })
      create_content('Artikel', { name: 'HEADLINE 1', tags: get_classification_ids('Tags', ['Tag 3']) })
      create_content('Artikel', { name: 'HEADLINE 2', tags: get_classification_ids('Tags', ['Tag 2', 'Nested Tag 1']) })
      create_content('Artikel', { name: 'HEADLINE 3', tags: get_classification_ids('Tags', ['Tag 3', 'Tag 2']) })
      create_content('Örtlichkeit', { name: 'PLACE 1', location: RGeo::Geographic.spherical_factory(srid: 4326).point(10, 10) })

      multiling = create_content('Artikel', { name: 'XYZ de' })
      multiling.external_source_id = DataCycleCore::ExternalSource.find_by(name: 'OutdoorActive').id
      multiling.created_by = DataCycleCore::User.find_by(email: 'admin@datacycle.at').id
      multiling.save!
      I18n.with_locale(:en) do
        multiling.set_data_hash(data_hash: { name: 'XYZ en' }.stringify_keys)
        multiling.save!
      end
    end

    test 'small helper functions' do
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').limit(1).count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').take(1).count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').offset(1).count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').skip(1).count)
    end

    test 'find multilingual entries' do
      assert_equal(1, DataCycleCore::Filter::Search.new([:de]).fulltext_search('XYZ').count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:en]).fulltext_search('XYZ').count)
      assert_equal(2, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').count)
    end

    test 'correctly count multilingual entries' do
      assert_equal(2, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').count_distinct)
    end

    test 'correctly filter out multilingual entries' do
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').distinct_by_content_id.count)
      assert_equal(2, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').distinct_by_content_id.first.available_locales.count)
    end

    test 'supplies a valid ranking' do
      search_for = 'AAA'
      order_string = DataCycleCore::Filter::Search.get_order_by_query_string(search_for)
      items = DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search(search_for).order(order_string)
      assert_equal(search_for, items.first.name)
    end

    test 'filter contents based on classifications' do
      items = DataCycleCore::Filter::Search.new(:de)
        .with_classification_alias_ids_without_recursion(find_alias_ids('Tags', 'Tag 3'))
      assert_equal(2, items.count)

      items = DataCycleCore::Filter::Search.new(:de)
        .classification_alias_ids(find_alias_ids('Tags', 'Tag 3'))
      assert_equal(3, items.count)
      # same_as
      items = DataCycleCore::Thing
        .with_classification_alias_ids(find_alias_ids('Tags', 'Tag 3'))
      assert_equal(3, items.count)

      items = DataCycleCore::Filter::Search.new(:de)
        .with_classification_aliases('Tags', 'Tag 3')
      assert_equal(3, items.count)
    end

    # test 'test method only_frontend_valid (excludes places)' do
    #   articles = @things + 5
    #   items = DataCycleCore::Filter::Search.new(:de)
    #     .classification_alias_ids(find_alias_ids('Inhaltstypen', ['Text']))
    #   assert_equal(articles, items.count)
    #   assert_equal(articles, items.only_frontend_valid.count)
    #   items = DataCycleCore::Filter::Search.new(:de)
    #     .classification_alias_ids(find_alias_ids('Inhaltstypen', ['Text', 'Örtlichkeit']))
    #   assert_equal(articles + 1, items.count)
    #   assert_equal(articles, items.only_frontend_valid.count)
    # end

    test 'test query for external_source' do
      external_source_id = DataCycleCore::ExternalSource.find_by(name: 'OutdoorActive').id
      items = DataCycleCore::Filter::Search.new(:de).external_source(external_source_id)
      assert_equal(1, items.count)
    end

    test 'test query for creator' do
      creator_id = DataCycleCore::User.find_by(email: 'admin@datacycle.at').id
      items = DataCycleCore::Filter::Search.new(:de).creator(creator_id)
      assert_equal(1, items.count)
    end

    test 'has method to include joined tables' do
      assert(DataCycleCore::Filter::Search.new(:de).content_includes.count.positive?)
    end

    test 'has method to check for validity_period' do
      assert(DataCycleCore::Filter::Search.new(:de).in_validity_period.count.positive?)
    end

    test 'has helper for created_since and modified_since' do
      items = DataCycleCore::Filter::Search.new(:de)
      all = items.count
      assert_equal(all, items.created_since((Time.zone.now - 1.hour).to_s).count)
      assert_equal(all, items.modified_since((Time.zone.now - 1.hour).to_s).count)
    end

    test 'supports geo queries' do
      assert_equal(1, DataCycleCore::Filter::Search.new(:de).within_box(1, 1, 20, 20).count)
    end

    private

    def create_content(template_name, data = {})
      content = DataCycleCore::TestPreparations.data_set_object(template_name)
      content.save!

      result = content.set_data_hash(data_hash: data.stringify_keys)
      raise 'InvalidData' if result[:error].present?
      content.save!
      content
    end

    def get_classification_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).map(&:classifications).flatten.map(&:id)
    end

    def find_alias_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).pluck(:id)
    end
  end
end
