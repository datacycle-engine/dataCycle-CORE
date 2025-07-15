# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module General
        module Links
          class ThingsTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
            include DataCycleCore::ApiV4Helper

            before(:all) do
              DataCycleCore::Thing.delete_all
              @routes = Engine.routes
              @user = User.find_by(email: 'tester@datacycle.at')
              @test_route = method(:api_v4_things_path)
              DataCycleCore::DummyDataHelper.create_data('poi')
              DataCycleCore::DummyDataHelper.create_data('event')

              # 3 Things are created by the dummy data helper
            end

            setup do
              sign_in(@user)
            end

            def test_route(params = {})
              @test_route.call(params)
            end

            test 'GET things full all sections' do
              get test_route(page: { number: 1, size: 1 })
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: 1 })
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').present?)

              get test_route(page: { number: 3, size: 1 })
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').present?)
            end

            test 'GET things full only @graph' do
              get test_route(page: { number: 1, size: 1 }, section: { meta: 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: 1 }, section: { meta: 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 3, size: 1 }, section: { meta: 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)
            end

            test 'GET things full only meta' do
              get test_route(page: { number: 1, size: 1 }, section: { '@graph': 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(3, json_data.dig('meta', 'total'))
              assert_equal(3, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: 1 }, section: { '@graph': 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(3, json_data.dig('meta', 'total'))
              assert_equal(3, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 3, size: 1 }, section: { '@graph': 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(3, json_data.dig('meta', 'total'))
              assert_equal(3, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)
            end

            test 'GET things full only links' do
              get test_route(page: { number: 1, size: 1 }, section: { '@graph': 0, meta: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: 1 }, section: { '@graph': 0, meta: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').present?)

              get test_route(page: { number: 3, size: 1 }, section: { '@graph': 0, meta: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').present?)
            end

            test 'GET things minimal all sections' do
              get test_route(page: { number: 1, size: 1 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: 1 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').present?)

              get test_route(page: { number: 3, size: 1 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').present?)
            end

            test 'GET things minimal only @graph' do
              get test_route(page: { number: 1, size: 1 }, section: { meta: 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: 1 }, section: { meta: 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 3, size: 1 }, section: { meta: 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_equal(1, json_data['@graph'].size)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)
            end

            test 'GET things minimal only meta' do
              get test_route(page: { number: 1, size: 1 }, section: { '@graph': 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(3, json_data.dig('meta', 'total'))
              assert_equal(3, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: 1 }, section: { '@graph': 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(3, json_data.dig('meta', 'total'))
              assert_equal(3, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 3, size: 1 }, section: { '@graph': 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(3, json_data.dig('meta', 'total'))
              assert_equal(3, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)
            end

            test 'GET things minimal only links' do
              get test_route(page: { number: 1, size: 1 }, section: { '@graph': 0, meta: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: 1 }, section: { '@graph': 0, meta: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').present?)

              get test_route(page: { number: 3, size: 1 }, section: { '@graph': 0, meta: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').present?)
            end

            test 'GET empty @graph' do
              DataCycleCore::Thing.delete_all
              get test_route
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].is_a?(Array))
              assert_equal(0, json_data['@graph'].size)

              get test_route(fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].is_a?(Array))
              assert_equal(0, json_data['@graph'].size)
            end
          end
        end
      end
    end
  end
end
