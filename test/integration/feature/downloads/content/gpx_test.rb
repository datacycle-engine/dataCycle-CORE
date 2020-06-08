# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Content
        class GpxTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers

          setup do
            @routes = Engine.routes
            @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'LifeCycleTestArtikel' })
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'render gpx for place' do
            place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'place3'))

            get download_thing_path(place), params: { serialize_format: 'gpx' }, headers: {
              referer: thing_path(place)
            }

            assert_response :success
            assert response.body.include?(place.name)
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal 1, xml.search('wpt').size
          end

          test 'render gpx for place and test downloads controller' do
            place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'place3'))

            get "/downloads/things/#{place.id}", params: { serialize_format: 'gpx' }, headers: {
              referer: thing_path(place)
            }

            assert_response :success
            assert response.body.include?(place.name)
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal 1, xml.search('wpt').size
          end

          test 'render gpx for place via APIv2' do
            place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'place3'))

            get gpx_api_v2_thing_path(id: place), headers: {
              referer: thing_path(place)
            }

            assert_response :success
            assert response.body.include?(place.name)
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal 1, xml.search('wpt').size
          end

          test 'render gpx for place via APIv3' do
            place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'place3'))

            get gpx_api_v3_thing_path(id: place), headers: {
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

            get download_thing_path(tour), params: { serialize_format: 'gpx' }, headers: {
              referer: thing_path(tour)
            }

            assert_response :success
            assert response.body.include?(tour.name)
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal 343, xml.search('trkpt').size
          end

          test 'render gpx for tour and test downloads controller' do
            tour = DataCycleCore::TestPreparations.create_content(template_name: 'Tour', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'tour1'))

            get "/downloads/things/#{tour.id}", params: { serialize_format: 'gpx' }, headers: {
              referer: thing_path(tour)
            }

            assert_response :success
            assert response.body.include?(tour.name)
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal 343, xml.search('trkpt').size
          end

          test 'render gpx for tour via APIv2' do
            tour = DataCycleCore::TestPreparations.create_content(template_name: 'Tour', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'tour1'))

            get gpx_api_v2_thing_path(id: tour), headers: {
              referer: thing_path(tour)
            }

            assert_response :success
            assert response.body.include?(tour.name)
            xml = Nokogiri::XML(response.body)
            assert xml.errors.blank?
            assert_equal 343, xml.search('trkpt').size
          end

          test 'render gpx for tour via APIv3' do
            tour = DataCycleCore::TestPreparations.create_content(template_name: 'Tour', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'tour1'))

            get gpx_api_v3_thing_path(id: tour), headers: {
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
    end
  end
end
