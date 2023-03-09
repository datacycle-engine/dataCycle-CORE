# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SearchTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @things = DataCycleCore::Thing.where(template: false).count
      create_content('Artikel', { name: 'AAA' })
      create_content('Artikel', { name: 'HEADLINE 1', tags: get_classification_ids('Tags', ['Tag 3']) })
      create_content('Artikel', { name: 'HEADLINE 2', tags: get_classification_ids('Tags', ['Tag 2', 'Nested Tag 1']) })
      create_content('Artikel', { name: 'HEADLINE 3', tags: get_classification_ids('Tags', ['Tag 3', 'Tag 2']) })
      create_content('Örtlichkeit', { name: 'PLACE 1', location: RGeo::Geographic.spherical_factory(srid: 4326).point(10, 10) })
      create_content('Event', { name: 'DDD', overlay: [{ name: 'EEE' }], sub_event: [{ name: 'FFF' }] })

      validity_period = { valid_from: Date.current.to_s, valid_until: Date.current.to_s }
      multiling = create_content('Artikel', { name: 'XYZ de', validity_period: validity_period })
      multiling.external_source_id = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system').id
      multiling.created_by = DataCycleCore::User.find_by(email: 'admin@datacycle.at').id
      multiling.save!
      I18n.with_locale(:en) do
        multiling.set_data_hash(data_hash: { name: 'XYZ en', validity_period: validity_period }.stringify_keys)
        multiling.save!
      end

      create_content('Artikel', { name: 'inactive article', validity_period: { valid_from: (Date.current - 2.weeks).to_s, valid_until: (Date.current - 1.week).to_s } })
      create_content('Artikel', { name: 'future inactive article', validity_period: { valid_from: (Date.current + 1.week).to_s, valid_until: (Date.current + 2.weeks).to_s } })

      factory3d = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)
      create_content('Tour', { name: 'TOUR 1', line: factory3d.multi_line_string([factory3d.line_string([factory3d.point(10, 10, 0), factory3d.point(20, 20, 0), factory3d.point(30, 30, 0)])]) })

      @alias_id1 = find_alias_ids('Tags', 'Tag 3')
      @alias_id2 = find_alias_ids('Tags', 'Tag 2')

      # SELECT st_Multi(ST_Polygon('LINESTRING(9 9, 25 9, 25 25, 9 25, 9 9)'::geometry, 4326)) as poly;
      DataCycleCore::ClassificationPolygon.create(admin_level: 2, geom: RGeo::Cartesian.factory(srid: 4326).parse_wkt('MULTIPOLYGON (((9 9, 25 9, 25 25, 9 25, 9 9)))'), classification_alias_id: @alias_id1[0], id: 1)

      # SELECT st_Multi(ST_Polygon('LINESTRING(40 40, 50 40, 50 50, 40 50, 40 40)'::geometry, 4326)) as poly;
      DataCycleCore::ClassificationPolygon.create(admin_level: 2, geom: RGeo::Cartesian.factory(srid: 4326).parse_wkt('MULTIPOLYGON (((40 40, 50 40, 50 50, 40 50, 40 40)))'), classification_alias_id: @alias_id2[0], id: 2)
    end

    test 'small helper functions' do
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').limit(1).count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').take(1).count)
      assert_equal(0, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').offset(1).count)
      assert_equal(0, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').skip(1).count)
    end

    test 'find multilingual entries' do
      assert_equal(1, DataCycleCore::Filter::Search.new([:de]).fulltext_search('XYZ').count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:en]).fulltext_search('XYZ').count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').count)
    end

    test 'correctly count multilingual entries' do
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').count)
    end

    test 'correctly filter out multilingual entries' do
      assert_equal(1, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').count)
      assert_equal(2, DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search('XYZ').first.available_locales.count)
    end

    test 'correctly filter out multilingual entries without fulltext search' do
      I18n.with_locale(:en) do
        create_content('Artikel', { name: 'AAA Englisch' })
      end

      assert_equal 10, DataCycleCore::Filter::Search.new(:de).count
      assert_equal 2, DataCycleCore::Filter::Search.new(:en).count
      assert_equal 11, DataCycleCore::Filter::Search.new(nil).count
    end

    test 'finds embedded_data' do
      assert_equal(1, DataCycleCore::Filter::Search.new([:de]).fulltext_search('EEE').count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:de]).fulltext_search('FFF').count)
    end

    test 'no search entries' do
      assert_equal(0, DataCycleCore::Thing.joins(:searches).where(content_type: 'embedded').count)
    end

    # TODO: change this test because with 1 result this test will always rank valid
    test 'supplies a valid ranking' do
      search_for = 'AAA'
      # TODO: refactor order query
      # order_string = DataCycleCore::Filter::Search.get_order_by_query_string(search_for)
      # items = DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search(search_for).order(order_string)
      items = DataCycleCore::Filter::Search.new([:de, :en]).fulltext_search(search_for)
      assert_equal(search_for, items.first.name)
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
      external_source_id = DataCycleCore::ExternalSystem.find_by(identifier: 'remote-system').id
      items = DataCycleCore::Filter::Search.new(:de).external_source(external_source_id)
      assert_equal(1, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_external_source(external_source_id)
      assert_equal(9, items.count)
    end

    test 'test query for subscriptions' do
      user = DataCycleCore::User.find_by(email: 'tester@datacycle.at')
      user.things_subscribed << DataCycleCore::Thing.where(template: false, template_name: 'Artikel').first

      items = DataCycleCore::Filter::Search.new(:de).subscribed_user_id(user.id)
      assert_equal(1, items.count)
    end

    test 'test query for creator' do
      creator_id = DataCycleCore::User.find_by(email: 'admin@datacycle.at').id
      items = DataCycleCore::Filter::Search.new(:de).creator(creator_id)
      assert_equal(1, items.count)
    end

    test 'test query for date_range (created_at)' do
      items = DataCycleCore::Filter::Search.new(:de)
        .date_range({ from: Date.current - 1.day, until: Date.current + 1.day }, 'created_at')
      assert_equal(10, items.count)

      items = DataCycleCore::Filter::Search.new(:de)
        .not_date_range({ from: Date.current - 1.day, until: Date.current + 1.day }, 'created_at')
      assert_equal(0, items.count)
    end

    test 'test query for validity_period' do
      items = DataCycleCore::Filter::Search.new(:de).validity_period({ from: Date.current, until: Date.current })
      assert_equal(8, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_validity_period({ from: Date.current, until: Date.current })
      assert_equal(2, items.count)
    end

    test 'test query for inactive items' do
      items = DataCycleCore::Filter::Search.new(:de).inactive_things({ from: nil, until: DateTime.current.end_of_day })
      assert_equal(2, items.count)

      items = DataCycleCore::Filter::Search.new(:de).inactive_things({ from: nil, until: (Date.current + 3.weeks).end_of_day })
      assert_equal(3, items.count)

      items = DataCycleCore::Filter::Search.new(:de).inactive_things({ from: Date.current.beginning_of_day, until: (Date.current + 3.weeks).end_of_day })
      assert_equal(2, items.count)
    end

    test 'test query for boolean -> duplicate_candidates' do
      assert DataCycleCore::Feature::DuplicateCandidate.enabled?
      asset1 = upload_image('test_rgb.jpeg')
      assert asset1.thumb_preview.present?
      DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: asset1.id })
      asset2 = upload_image('test_rgb.png')
      assert asset2.thumb_preview.present?
      DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2', asset: asset2.id })
      asset3 = upload_image('test_rgb.jpeg')
      assert asset3.thumb_preview.present?
      image3 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 3', asset: asset3.id })

      DataCycleCore::Thing
        .where(template: false, external_source_id: nil, external_key: nil, template_name: 'Bild')
        .where.not(content_type: 'embedded')
        .find_each(&:create_duplicate_candidates)

      image3.duplicate_candidates.each { |t| t.thing_duplicate.update(false_positive: true) }

      items = DataCycleCore::Filter::Search.new(:de).boolean('true', 'duplicate_candidates')
      assert_equal(2, items.count)

      items = DataCycleCore::Filter::Search.new(:de).boolean('false', 'duplicate_candidates')
      assert_equal(11, items.count)
    end

    test 'test query for classification_tree' do
      tree_label_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
      items = DataCycleCore::Filter::Search.new(:de).classification_tree_ids(tree_label_id)
      assert_equal(3, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_classification_tree_ids(tree_label_id)
      assert_equal(7, items.count)
    end

    test 'has method to include joined tables' do
      assert(DataCycleCore::Filter::Search.new(:de).content_includes.count.positive?)
    end

    test 'has method to check for validity_period' do
      assert(DataCycleCore::Filter::Search.new(:de).in_validity_period.count.positive?)
    end

    test 'has helper for created_at and modified_at' do
      items = DataCycleCore::Filter::Search.new(:de)
      all = items.count
      assert_equal(all, items.created_at({ min: (Time.zone.now - 1.hour).to_s }).count)
      assert_equal(all, items.modified_at({ min: (Time.zone.now - 1.hour).to_s }).count)
    end

    test 'supports geo queries' do
      assert_equal(2, DataCycleCore::Filter::Search.new(:de).within_box(1, 1, 20, 20).count)
    end

    test 'supports geo radius' do
      assert_equal(2, DataCycleCore::Filter::Search.new(:de).geo_radius({ 'lon' => '10', 'lat' => '10', 'distance' => '10' }).count)
    end

    test 'supports geo search within polygon' do
      assert_equal(2, DataCycleCore::Filter::Search.new(:de).geo_within_classification(@alias_id1).count)
      assert_equal(0, DataCycleCore::Filter::Search.new(:de).geo_within_classification(@alias_id2).count)
    end

    test 'supports geo search not within polygon' do
      assert_equal(0, DataCycleCore::Filter::Search.new(:de).not_geo_within_classification(@alias_id1).count)
      assert_equal(2, DataCycleCore::Filter::Search.new(:de).not_geo_within_classification(@alias_id2).count)
    end

    # test 'test thesaurus is installed' do
    #   result = ActiveRecord::Base.connection.exec_query("SELECT to_tsvector('german', 'DataCycle') as akronym")
    #   assert_equal("'dc':1", result.first['akronym'])
    # end

    test 'test query for relation_filter' do
      image = create_content('Bild', { name: 'Test Bild Linked' })
      article = create_content('Artikel', { name: 'Test Article Linked', image: [image.id] })

      assert_equal(1, DataCycleCore::Filter::Search.new(:de).like_relation_filter([image.id], 'image').count) # find the article
      assert_equal(article.id, DataCycleCore::Filter::Search.new(:de).like_relation_filter([image.id], 'image').query.first.id) # find the article
      assert_equal(11, DataCycleCore::Filter::Search.new(:de).not_like_relation_filter([image.id], 'image').count) # find all except article
      assert DataCycleCore::Filter::Search.new(:de).not_like_relation_filter([image.id], 'image').query.ids.exclude?(article.id) # find all except article
    end

    test 'test typeahead, specific language' do
      words_typeahead = DataCycleCore::Filter::Search.new(:en).typeahead('xyz', ['en']).to_a
      assert_equal(3, words_typeahead.size)
      assert_equal('xyz', words_typeahead.first.dig('word'))
      assert_equal(0.0, words_typeahead.first.dig('score'))
      assert_equal('xyz-en', words_typeahead.second.dig('word'))
    end

    test 'test typeahead, specific language, typeahead in german' do
      words_typeahead = DataCycleCore::Filter::Search.new(:en).typeahead('xyz', ['de']).to_a
      assert_equal('xyz-de', words_typeahead.second.dig('word'))
    end

    test 'limit for typeahead' do
      words_typeahead = DataCycleCore::Filter::Search.new(:en).typeahead('xyz', ['en'], 1).to_a
      assert_equal(1, words_typeahead.size)
      words_typeahead = DataCycleCore::Filter::Search.new(:en).typeahead('xyz', ['en'], 2).to_a
      assert_equal(2, words_typeahead.size)
      words_typeahead = DataCycleCore::Filter::Search.new(:en).typeahead('xyz', ['en'], 100).to_a
      assert_equal(3, words_typeahead.size)
    end

    private

    def create_content(template_name, data = {})
      DataCycleCore::TestPreparations.create_content(template_name: template_name, data_hash: data)
    end

    def get_classification_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).map(&:classifications).flatten.map(&:id)
    end

    def find_alias_ids(tree_name, *alias_names)
      DataCycleCore::ClassificationAlias.for_tree(tree_name).with_name(alias_names).pluck(:id)
    end
  end
end
