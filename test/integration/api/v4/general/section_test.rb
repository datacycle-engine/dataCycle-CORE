# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module General
        class SectionTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          include DataCycleCore::ApiV4Helper

          before(:all) do
            DataCycleCore::Thing.where(template: false).delete_all
            @routes = Engine.routes
            @content = DataCycleCore::DummyDataHelper.create_data('poi')
            @content.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@content.longitude, @content.latitude)
            @content.save
            @content2 = DataCycleCore::DummyDataHelper.create_data('event')
            @content2.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_period: { start_date: 8.days.ago, end_date: 8.days.from_now } })
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'GET default' do
            get api_v4_things_path
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(3, json_data['@graph'].size)
            assert_equal(2, json_data['@context'].size)
            assert(json_data['meta']['total'].present?)
            assert(json_data['meta']['pages'].present?)
            assert(json_data.key?('links'))
            assert(json_data.dig('links').blank?)
          end

          test 'GET page size: 1' do
            get api_v4_things_path(page: { size: 1 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert_equal(2, json_data['@context'].size)
            assert(json_data['meta']['total'].present?)
            assert(json_data['meta']['pages'].present?)
            assert(json_data['links']['next'].present?)
          end

          test 'GET section meta: 0' do
            get api_v4_things_path(section: { meta: 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(3, json_data['@graph'].size)
            assert_equal(2, json_data['@context'].size)
            assert(json_data['meta'].blank?)
            assert(json_data.key?('links'))
          end

          test 'GET page size: 1 section meta: 0' do
            get api_v4_things_path(page: { size: 1 }, section: { meta: 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert_equal(2, json_data['@context'].size)
            assert(json_data['meta'].blank?)
            assert(json_data['links']['next'].present?)
          end

          test 'GET page size: 1 section links: 0 ' do
            get api_v4_things_path(page: { size: 1 }, section: { links: 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert_equal(2, json_data['@context'].size)
            assert(json_data['meta'].present?)
            assert(json_data['links'].blank?)
          end

          test 'GET page size: 1 section context: 0 ' do
            get api_v4_things_path(page: { size: 1 }, section: { '@context': 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert(json_data['@context'].blank?)
            assert(json_data['meta'].present?)
            assert(json_data['links'].present?)
          end

          test 'GET page size: 1 section graph: 0 ' do
            get api_v4_things_path(page: { size: 1 }, section: { '@graph': 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert(json_data['@graph'].blank?)
            assert(json_data['@context'].present?)
            assert(json_data['meta'].present?)
            assert(json_data['links'].present?)
          end

          test 'POST default' do
            post api_v4_things_path
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(3, json_data['@graph'].size)
            assert_equal(2, json_data['@context'].size)
            assert(json_data['meta']['total'].present?)
            assert(json_data['meta']['pages'].present?)
            assert(json_data.key?('links'))
            assert(json_data.dig('links').blank?)
          end

          test 'POST page size: 1' do
            post api_v4_things_path(page: { size: 1 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert_equal(2, json_data['@context'].size)
            assert(json_data['meta']['total'].present?)
            assert(json_data['meta']['pages'].present?)
            assert(json_data['links']['next'].present?)
          end

          test 'POST section meta: 0' do
            post api_v4_things_path(section: { meta: 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(3, json_data['@graph'].size)
            assert_equal(2, json_data['@context'].size)
            assert(json_data['meta'].blank?)
            assert(json_data.key?('links'))
          end

          test 'POST page size: 1 section meta: 0' do
            post api_v4_things_path(page: { size: 1 }, section: { meta: 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert_equal(2, json_data['@context'].size)
            assert(json_data['meta'].blank?)
            assert(json_data['links']['next'].present?)
          end

          test 'POST page size: 1 section links: 0 ' do
            post api_v4_things_path(page: { size: 1 }, section: { links: 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert_equal(2, json_data['@context'].size)
            assert(json_data['meta'].present?)
            assert(json_data['links'].blank?)
          end

          test 'POST page size: 1 section context: 0 ' do
            post api_v4_things_path(page: { size: 1 }, section: { '@context': 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert(json_data['@context'].blank?)
            assert(json_data['meta'].present?)
            assert(json_data['links'].present?)
          end

          test 'POST page size: 1 section graph: 0 ' do
            post api_v4_things_path(page: { size: 1 }, section: { '@graph': 0 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert(json_data['@graph'].blank?)
            assert(json_data['@context'].present?)
            assert(json_data['meta'].present?)
            assert(json_data['links'].present?)
          end

          test 'POST page offset with paging or limit ' do
            post api_v4_things_path
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data_full = JSON.parse(response.body)

            second = json_data_full['@graph'].second
            third = json_data_full['@graph'].third

            post api_v4_things_path(page: { size: 1, offset: 1 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data['@graph'].size)
            assert_equal(json_data['@graph'].first.dig('@id'), second.dig('@id'))
            assert(json_data['@context'].present?)
            assert(json_data['meta'].present?)
            assert(json_data['links'].present?)

            post api_v4_things_path(page: { size: 1, offset: 1, number: 2 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data['@graph'].size)
            assert_equal(json_data['@graph'].first.dig('@id'), third.dig('@id'))
            assert(json_data['@context'].present?)
            assert(json_data['meta'].present?)
            assert(json_data['links'].present?)

            post api_v4_things_path(page: { offset: 2, limit: 1 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)
            assert_equal(1, json_data['@graph'].size)
            assert_equal(json_data['@graph'].first.dig('@id'), third.dig('@id'))
            assert(json_data['@context'].present?)
            assert(json_data['meta'].present?)
            assert(json_data['links'].blank?)
          end

          test 'POST page limit: 1 ' do
            post api_v4_things_path(page: { limit: 1 })
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = JSON.parse(response.body)

            assert_equal(1, json_data['@graph'].size)
            assert(json_data['@context'].present?)
            assert(json_data['meta'].present?)
            assert(json_data['links'].blank?)
          end
        end
      end
    end
  end
end
