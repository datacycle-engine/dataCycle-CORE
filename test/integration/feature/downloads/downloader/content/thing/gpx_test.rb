# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    module Downloads
      module Downloader
        module Content
          module Thing
            class GpxTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                @routes = Engine.routes
                @current_user = User.find_by(email: 'tester@datacycle.at')
                @serialize_config = DataCycleCore.features[:serialize].deep_dup
                @download_config = DataCycleCore.features[:download].deep_dup
                @place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'place3'))
                @tour = DataCycleCore::TestPreparations.create_content(template_name: 'Tour', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'tour1'))
              end

              setup do
                sign_in(@current_user)
              end

              test 'render gpx for place' do
                get download_thing_path(@place), params: { serialize_format: 'gpx' }, headers: {
                  referer: thing_path(@place)
                }

                assert_response :success
                assert response.body.include?(@place.name)
                xml = Nokogiri::XML(response.body)
                assert xml.errors.blank?
                assert_equal 1, xml.search('wpt').size
              end

              test 'render gpx for place and test downloads controller' do
                get "/downloads/things/#{@place.id}", params: { serialize_format: 'gpx' }, headers: {
                  referer: thing_path(@place)
                }

                assert_response :success
                assert response.body.include?(@place.name)
                xml = Nokogiri::XML(response.body)
                assert xml.errors.blank?
                assert_equal 1, xml.search('wpt').size
              end

              test 'render gpx for place via APIv2' do
                get gpx_api_v2_thing_path(id: @place), headers: {
                  referer: thing_path(@place)
                }

                assert_response :success
                assert response.body.include?(@place.name)
                xml = Nokogiri::XML(response.body)
                assert xml.errors.blank?
                assert_equal 1, xml.search('wpt').size
              end

              test 'render gpx for place via APIv3' do
                get gpx_api_v3_thing_path(id: @place), headers: {
                  referer: thing_path(@place)
                }

                assert_response :success
                assert response.body.include?(@place.name)
                xml = Nokogiri::XML(response.body)
                assert xml.errors.blank?
                assert_equal 1, xml.search('wpt').size
              end

              test 'render gpx for tour' do
                get download_thing_path(@tour), params: { serialize_format: 'gpx' }, headers: {
                  referer: thing_path(@tour)
                }

                assert_response :success
                assert response.body.include?(@tour.name)
                xml = Nokogiri::XML(response.body)
                assert xml.errors.blank?
                assert_equal 343, xml.search('trkpt').size
              end

              test 'render gpx for tour and test downloads controller' do
                get "/downloads/things/#{@tour.id}", params: { serialize_format: 'gpx' }, headers: {
                  referer: thing_path(@tour)
                }

                assert_response :success
                assert response.body.include?(@tour.name)
                xml = Nokogiri::XML(response.body)
                assert xml.errors.blank?
                assert_equal 343, xml.search('trkpt').size
              end

              test 'render gpx for tour via APIv2' do
                get gpx_api_v2_thing_path(id: @tour), headers: {
                  referer: thing_path(@tour)
                }

                assert_response :success
                assert response.body.include?(@tour.name)
                xml = Nokogiri::XML(response.body)
                assert xml.errors.blank?
                assert_equal 343, xml.search('trkpt').size
              end

              test 'render gpx for tour via APIv3' do
                get gpx_api_v3_thing_path(id: @tour), headers: {
                  referer: thing_path(@tour)
                }

                assert_response :success
                assert response.body.include?(@tour.name)
                xml = Nokogiri::XML(response.body)
                assert xml.errors.blank?
                assert_equal 343, xml.search('trkpt').size
              end
            end
          end
        end
      end
    end
  end
end
