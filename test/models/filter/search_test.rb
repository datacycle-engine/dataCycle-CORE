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
      create_content('Event', { name: 'DDD', overlay: [{ name: 'EEE' }], sub_event: [{ name: 'FFF' }] })

      validity_period = { valid_from: DateTime.current.beginning_of_day.to_s, valid_until: DateTime.current.end_of_day.to_s }
      multiling = create_content('Artikel', { name: 'XYZ de', validity_period: validity_period })
      multiling.external_source_id = DataCycleCore::ExternalSource.find_by(name: 'OutdoorActive').id
      multiling.created_by = DataCycleCore::User.find_by(email: 'admin@datacycle.at').id
      multiling.save!
      I18n.with_locale(:en) do
        multiling.set_data_hash(data_hash: { name: 'XYZ en', validity_period: validity_period }.stringify_keys)
        multiling.save!
      end

      create_content('Artikel', { name: 'inactive article', validity_period: { valid_from: (DateTime.current - 2.weeks).beginning_of_day.to_s, valid_until: (DateTime.current - 1.week).end_of_day.to_s } })
      create_content('Artikel', { name: 'future inactive article', validity_period: { valid_from: (DateTime.current + 1.week).beginning_of_day.to_s, valid_until: (DateTime.current + 2.weeks).end_of_day.to_s } })
    end

    def upload_image(file_name)
      file_path = File.join(DataCycleCore::TestPreparations::ASSETS_PATH, 'images', file_name)
      image = DataCycleCore::Image.new(file: File.open(file_path))
      image.save
      image
    end

    def create_schedule(dtstart, dtend, duration)
      schedule = DataCycleCore::Schedule.new
      dtstart = dtstart
      dtend = dtend
      schedule.schedule_object = IceCube::Schedule.new(dtstart, { duration: duration.to_i }) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily.hour_of_day(dtstart.hour).until(dtend))
      end
      schedule
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

    test 'finds embedded_data' do
      assert_equal(1, DataCycleCore::Filter::Search.new([:de]).fulltext_search('EEE').count)
      assert_equal(1, DataCycleCore::Filter::Search.new([:de]).fulltext_search('FFF').count)
    end

    test 'no search entries' do
      assert_equal(0, DataCycleCore::Thing.joins(:searches).where(content_type: 'embedded').count)
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

      items = DataCycleCore::Filter::Search.new(:de)
        .not_classification_alias_ids(find_alias_ids('Tags', 'Tag 2'))
      assert_equal(7, items.count)
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

      items = DataCycleCore::Filter::Search.new(:de).not_external_source(external_source_id)
      assert_equal(8, items.count)
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
      assert_equal(9, items.count)

      items = DataCycleCore::Filter::Search.new(:de)
        .not_date_range({ from: Date.current - 1.day, until: Date.current + 1.day }, 'created_at')
      assert_equal(0, items.count)
    end

    test 'test query for validity_period' do
      items = DataCycleCore::Filter::Search.new(:de).validity_period({ from: Date.current, until: Date.current })
      assert_equal(7, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_validity_period({ from: Date.current, until: Date.current })
      assert_equal(2, items.count)
    end

    test 'test query for event_schedule' do
      event = create_content('Event', { name: 'DDD2' })
      event.set_data_hash(data_hash: { event_schedule: [{
        'start_time' => {
          'time' => DateTime.current,
          'zone' => 'Vienna'
        },
        'rtimes' => [],
        'duration' => 1.hour.to_i
      }] }, partial_update: true)

      items = DataCycleCore::Filter::Search.new(:de).schedule_search(Date.current, Date.current)
      assert_equal(1, items.count)
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
      DataCycleCore::ImageUploader.enable_processing = true
      assert DataCycleCore::Feature::DuplicateCandidate.enabled?
      asset1 = upload_image 'test_rgb.jpg'
      DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', asset: asset1.id })
      asset2 = upload_image 'test_rgb.png'
      DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2', asset: asset2.id })
      asset3 = upload_image 'test_rgb.jpg'
      image3 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 3', asset: asset3.id })

      DataCycleCore::Thing
        .where(template: false, external_source_id: nil, external_key: nil, template_name: 'Bild')
        .where.not(content_type: 'embedded')
        .find_each(&:create_duplicate_candidates)

      image3.duplicate_candidates.each { |t| t.thing_duplicate.update(false_positive: true) }

      items = DataCycleCore::Filter::Search.new(:de).boolean('true', 'duplicate_candidates')
      assert_equal(2, items.count)

      items = DataCycleCore::Filter::Search.new(:de).boolean('false', 'duplicate_candidates')
      assert_equal(10, items.count)
      DataCycleCore::ImageUploader.enable_processing = false
    end

    test 'test query for classification_tree' do
      tree_label_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
      items = DataCycleCore::Filter::Search.new(:de).classification_tree_ids(tree_label_id)
      assert_equal(3, items.count)

      items = DataCycleCore::Filter::Search.new(:de).not_classification_tree_ids(tree_label_id)
      assert_equal(6, items.count)
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

    test 'supports geo radius' do
      assert_equal(1, DataCycleCore::Filter::Search.new(:de).geo_radius({ 'lon' => '10', 'lat' => '10', 'distance' => '10' }).count)
    end

    test 'supports geo search within polygon' do
      alias_id = find_alias_ids('Tags', 'Tag 3')

      # SELECT ST_Transform(st_Multi(ST_Polygon('LINESTRING(9 9, 11 9, 11 11, 9 11, 9 9)'::geometry, 4326)),3035) as poly;
      # MULTIPOLYGON (((4202934.644239654 -1448504.9553259471, 4439065.355760346 -1448504.9553259471, 4437568.345904839 -1241795.1900585638, 4204431.654095161 -1241795.1900585638, 4202934.644239654 -1448504.9553259471)))
      DataCycleCore::ClassificationPolygon.create(admin_level: 2, geom: RGeo::Cartesian.factory(srid: 3035).parse_wkt('MULTIPOLYGON (((4202934.644239654 -1448504.9553259471, 4439065.355760346 -1448504.9553259471, 4437568.345904839 -1241795.1900585638, 4204431.654095161 -1241795.1900585638, 4202934.644239654 -1448504.9553259471)))'), classification_alias_id: alias_id[0], id: 1)

      assert_equal(1, DataCycleCore::Filter::Search.new(:de).geo_within_classification(alias_id).count)
    end

    test 'supports geo search not within polygon' do
      alias_id = find_alias_ids('Tags', 'Tag 2')

      # SELECT ST_Transform(st_Multi(ST_Polygon('LINESTRING(19 19, 21 19, 21 21, 19 21, 19 19)'::geometry, 4326)),3035) as poly;
      # MULTIPOLYGON (((5306514.722896763 -348639.8906273227, 5524232.402444027 -322040.9900201331, 5503178.7795628775 -109815.77694823965, 5289291.622551791 -136167.21943095466, 5306514.722896763 -348639.8906273227)))
      DataCycleCore::ClassificationPolygon.create(admin_level: 2, geom: RGeo::Cartesian.factory(srid: 3035).parse_wkt('MULTIPOLYGON (((5306514.722896763 -348639.8906273227, 5524232.402444027 -322040.9900201331, 5503178.7795628775 -109815.77694823965, 5289291.622551791 -136167.21943095466, 5306514.722896763 -348639.8906273227)))'), classification_alias_id: alias_id[0], id: 2)

      assert_equal(0, DataCycleCore::Filter::Search.new(:de).geo_within_classification(alias_id).count)
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
