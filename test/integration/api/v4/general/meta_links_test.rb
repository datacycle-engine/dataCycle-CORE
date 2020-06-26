# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module General
        class MetaLinksTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers
          include DataCycleCore::ApiV4Helper

          setup do
            DataCycleCore::Thing.where(template: false).delete_all
            @routes = Engine.routes
            @content = DataCycleCore::DummyDataHelper.create_data('poi')
            @content.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@content.longitude, @content.latitude)
            @content.save
            @content2 = DataCycleCore::DummyDataHelper.create_data('event')
            @content2.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_period: { start_date: 8.days.ago, end_date: 8.days.from_now } })
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'GET default' do
            get api_v4_things_path
            assert_response :success

            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)

            assert_equal(3, json_data['@graph'].size)
            assert_equal(true, json_data['meta']['total'].present?)
            assert_equal(true, json_data['meta']['pages'].present?)
            assert_equal(true, json_data.key?('links'))
            assert_equal(true, json_data.dig('links').blank?)
          end

          test 'GET page size: 1' do
            get api_v4_things_path(page: { size: 1 })
            assert_response :success

            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert_equal(true, json_data['meta']['total'].present?)
            assert_equal(true, json_data['meta']['pages'].present?)
            assert_equal(true, json_data['links']['next'].present?)
          end

          test 'GET page count: 0' do
            get api_v4_things_path(page: { count: 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)

            assert_equal(3, json_data['@graph'].size)
            assert_equal(true, json_data['meta'].blank?)
            assert_equal(true, json_data.key?('links'))
          end

          test 'GET page size: 1 count: 0' do
            get api_v4_things_path(page: { size: 1, count: 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert_equal(true, json_data['meta'].blank?)
            assert_equal(true, json_data['links']['next'].present?)
          end

          test 'POST default' do
            post api_v4_things_path
            assert_response :success

            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)

            assert_equal(3, json_data['@graph'].size)
            assert_equal(true, json_data['meta']['total'].present?)
            assert_equal(true, json_data['meta']['pages'].present?)
            assert_equal(true, json_data.key?('links'))
            assert_equal(true, json_data.dig('links').blank?)
          end

          test 'POST page size: 1' do
            post api_v4_things_path(page: { size: 1 })
            assert_response :success

            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert_equal(true, json_data['meta']['total'].present?)
            assert_equal(true, json_data['meta']['pages'].present?)
            assert_equal(true, json_data['links']['next'].present?)
          end

          test 'POST page count: 0' do
            post api_v4_things_path(page: { count: 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)

            assert_equal(3, json_data['@graph'].size)
            assert_equal(true, json_data['meta'].blank?)
            assert_equal(true, json_data.key?('links'))
          end

          test 'POST page size: 1 count: 0' do
            post api_v4_things_path(page: { size: 1, count: 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert_equal(true, json_data['meta'].blank?)
            assert_equal(true, json_data['links']['next'].present?)
          end
        end
      end
    end
  end
end
