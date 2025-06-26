# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module General
        module Links
          class ConceptSchemesTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
            include DataCycleCore::ApiV4Helper

            before(:all) do
              @routes = Engine.routes
              @user = User.find_by(email: 'tester@datacycle.at')
              @test_route = method(:api_v4_concept_schemes_path)
              @total = DataCycleCore::ConceptScheme.where(internal: false).visible('api').size
              @page_size = (@total.to_f / 3).ceil
              @pages = (@total.to_f / @page_size).ceil
            end

            setup do
              sign_in(@user)
            end

            def test_route(params = {})
              @test_route.call(params)
            end

            test 'GET concept_schemes full all sections' do
              get test_route(page: { number: 1, size: @page_size })
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: @page_size })
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').present?)

              get test_route(page: { number: 3, size: @page_size })
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').present?)
            end

            test 'GET concept_schemes full only @graph' do
              get test_route(page: { number: 1, size: @page_size }, section: { meta: 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: @page_size }, section: { meta: 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 3, size: @page_size }, section: { meta: 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)
            end

            test 'GET concept_schemes full only meta' do
              get test_route(page: { number: 1, size: @page_size }, section: { '@graph': 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(@total, json_data.dig('meta', 'total'))
              assert_equal(@pages, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: @page_size }, section: { '@graph': 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(@total, json_data.dig('meta', 'total'))
              assert_equal(@pages, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 3, size: @page_size }, section: { '@graph': 0, links: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(@total, json_data.dig('meta', 'total'))
              assert_equal(@pages, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)
            end

            test 'GET concept_schemes full only links' do
              get test_route(page: { number: 1, size: @page_size }, section: { '@graph': 0, meta: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: @page_size }, section: { '@graph': 0, meta: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').present?)

              get test_route(page: { number: 3, size: @page_size }, section: { '@graph': 0, meta: 0 })
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').present?)
            end

            test 'GET concept_schemes minimal all sections' do
              get test_route(page: { number: 1, size: @page_size }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: @page_size }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').present?)

              get test_route(page: { number: 3, size: @page_size }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').present?)
              assert(json_data.dig('meta', 'pages').present?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').present?)
            end

            test 'GET concept_schemes minimal only @graph' do
              get test_route(page: { number: 1, size: @page_size }, section: { meta: 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: @page_size }, section: { meta: 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 3, size: @page_size }, section: { meta: 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert(json_data['@graph'].present?)
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)
            end

            test 'GET concept_schemes minimal only meta' do
              get test_route(page: { number: 1, size: @page_size }, section: { '@graph': 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(@total, json_data.dig('meta', 'total'))
              assert_equal(@pages, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: @page_size }, section: { '@graph': 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(@total, json_data.dig('meta', 'total'))
              assert_equal(@pages, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 3, size: @page_size }, section: { '@graph': 0, links: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert_equal(@total, json_data.dig('meta', 'total'))
              assert_equal(@pages, json_data.dig('meta', 'pages'))
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').blank?)
            end

            test 'GET concept_schemes minimal only links' do
              get test_route(page: { number: 1, size: @page_size }, section: { '@graph': 0, meta: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').blank?)

              get test_route(page: { number: 2, size: @page_size }, section: { '@graph': 0, meta: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').present?)
              assert(json_data.dig('links', 'prev').present?)

              get test_route(page: { number: 3, size: @page_size }, section: { '@graph': 0, meta: 0 }, fields: '@id')
              assert_response :success

              json_data = response.parsed_body

              assert_nil(json_data['@graph'])
              assert(json_data.dig('meta', 'total').blank?)
              assert(json_data.dig('meta', 'pages').blank?)
              assert(json_data.dig('links', 'next').blank?)
              assert(json_data.dig('links', 'prev').present?)
            end
          end
        end
      end
    end
  end
end
