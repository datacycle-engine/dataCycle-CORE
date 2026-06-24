# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SearchGeoshapeTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @place_inside = create_content('Örtlichkeit', { name: 'PLACE 1', location: RGeo::Geographic.spherical_factory(srid: 4326).point(9.75478205759083, 47.272276443355025) })
      @place_outside = create_content('Örtlichkeit', { name: 'PLACE 2', location: RGeo::Geographic.spherical_factory(srid: 4326).point(9.68076549690997, 47.31632943824184) })
      @polyline = 'oy|_Hy_qz@htMrkJn{MszIacEi`c@urRn}KayBxpU'
      @wkt = 'POLYGON((9.758846327544177 47.33863917786354,9.700506756611873 47.26354837128608,9.75612733107468 47.18730715096737,9.940659638756642 47.21868324432617,9.874341927525677 47.319106886673836,9.758846327544177 47.33863917786354))'
      @geojson = '{"type":"Polygon","coordinates":[[[9.758846328,47.338639178],[9.700506757,47.263548371],[9.756127331,47.187307151],[9.940659639,47.218683244],[9.874341928,47.319106887],[9.758846328,47.338639178]]]}'
      @polyline_line = '{cs_Hc~~{@srLnySqvMibJfcCgfMffUqtD'
      @wkt_line = 'LINESTRING(9.994102997019667 47.28909574960019,9.887456664601274 47.35880433186321,9.944314005123971 47.43425379429462,10.017150746515625 47.41308543503254,10.046197223440373 47.2992850730007)'
      @geojson_line = '{"type":"LineString","coordinates":[[9.994102997,47.28909575],[9.887456665,47.358804332],[9.944314005,47.434253794],[10.017150747,47.413085435],[10.046197223,47.299285073]]}'
    end

    test 'supports geo search within polygon' do
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).within_shape({ 'polygon' => @polyline }).count)
      assert_equal([@place_inside.id], DataCycleCore::Filter::Search.new(locale: :de).within_shape({ 'polygon' => @polyline }).pluck(:id))
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).within_shape({ 'polygon' => @wkt }).count)
      assert_equal([@place_inside.id], DataCycleCore::Filter::Search.new(locale: :de).within_shape({ 'polygon' => @wkt }).pluck(:id))
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).within_shape({ 'polygon' => @geojson }).count)
      assert_equal([@place_inside.id], DataCycleCore::Filter::Search.new(locale: :de).within_shape({ 'polygon' => @geojson }).pluck(:id))
    end

    test 'supports geo search not within polygon' do
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).not_within_shape({ 'polygon' => @polyline }).count)
      assert_equal([@place_outside.id], DataCycleCore::Filter::Search.new(locale: :de).not_within_shape({ 'polygon' => @polyline }).pluck(:id))
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).not_within_shape({ 'polygon' => @wkt }).count)
      assert_equal([@place_outside.id], DataCycleCore::Filter::Search.new(locale: :de).not_within_shape({ 'polygon' => @wkt }).pluck(:id))
      assert_equal(1, DataCycleCore::Filter::Search.new(locale: :de).not_within_shape({ 'polygon' => @geojson }).count)
      assert_equal([@place_outside.id], DataCycleCore::Filter::Search.new(locale: :de).not_within_shape({ 'polygon' => @geojson }).pluck(:id))
    end

    test 'within_shape fails with wrong type' do
      assert_raises(DataCycleCore::Error::Api::BadRequestError) do
        DataCycleCore::Filter::Search.new(locale: :de).within_shape({ 'line' => @wkt }).count
      end
      assert_raises(DataCycleCore::Error::Api::BadRequestError) do
        DataCycleCore::Filter::Search.new(locale: :de).within_shape({ 'line' => @geojson }).count
      end
      assert_raises(ActiveRecord::StatementInvalid) do
        DataCycleCore::Filter::Search.new(locale: :de).within_shape({ 'polygon' => @polyline_line }).count
      end
      assert_raises(DataCycleCore::Error::Api::BadRequestError) do
        DataCycleCore::Filter::Search.new(locale: :de).within_shape({ 'polygon' => @wkt_line }).count
      end
      assert_raises(DataCycleCore::Error::Api::BadRequestError) do
        DataCycleCore::Filter::Search.new(locale: :de).within_shape({ 'polygon' => @geojson_line }).count
      end
    end
  end
end
