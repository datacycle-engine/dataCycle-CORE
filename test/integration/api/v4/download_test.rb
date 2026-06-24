# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module V4
      class DownloadTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @routes = Engine.routes
          @current_user = User.find_by(email: 'tester@datacycle.at')
          @place = DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'place3'))
          @endpoint = DataCycleCore::TestPreparations.create_watch_list(name: 'GPX Download Endpoint')
          @place.watch_lists << @endpoint
        end

        setup do
          sign_in(@current_user)
        end

        test 'download single thing as gpx via serialize_format (snake_case)' do
          get api_v4_download_thing_path(id: @endpoint.id, content_id: @place.id), params: { serialize_format: 'gpx' }

          assert_response :success
          assert_includes response.body, @place.name
          xml = Nokogiri::XML(response.body)

          assert_predicate xml.errors, :blank?
          assert_equal 1, xml.search('wpt').size
        end

        test 'download single thing as gpx via serializeFormat (camelCase)' do
          get api_v4_download_thing_path(id: @endpoint.id, content_id: @place.id), params: { serializeFormat: 'gpx' }

          assert_response :success
          assert_includes response.body, @place.name
          xml = Nokogiri::XML(response.body)

          assert_predicate xml.errors, :blank?
          assert_equal 1, xml.search('wpt').size
        end

        test 'download single thing as gpx via serializeFormat (camelCase) over HTTP-POST' do
          post api_v4_download_thing_path(id: @endpoint.id, content_id: @place.id), params: { serializeFormat: 'gpx' }, as: :json

          assert_response :success
          assert_includes response.body, @place.name
          xml = Nokogiri::XML(response.body)

          assert_predicate xml.errors, :blank?
          assert_equal 1, xml.search('wpt').size
        end
      end
    end
  end
end
