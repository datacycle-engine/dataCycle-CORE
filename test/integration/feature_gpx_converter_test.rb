# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class FeatureGpxConverterTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'LifeCycleTestArtikel' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'render gpx for place' do
      place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'place3'))

      get gpx_thing_path(place), params: {}, headers: {
        referer: thing_path(place)
      }

      assert_response :success
      assert response.body.include?(place.name)
      xml = Nokogiri::XML(response.body)
      assert xml.errors.blank?
      assert_equal 1, xml.search('wpt').size
    end

    test 'render gpx for tour' do
      tour = DataCycleCore::TestPreparations.create_content(template_name: 'Tour', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'tour1'))

      get gpx_thing_path(tour), params: {}, headers: {
        referer: thing_path(tour)
      }

      assert_response :success
      assert response.body.include?(tour.name)
      xml = Nokogiri::XML(response.body)
      assert xml.errors.blank?
      assert_equal 343, xml.search('trkpt').size
    end
  end
end
