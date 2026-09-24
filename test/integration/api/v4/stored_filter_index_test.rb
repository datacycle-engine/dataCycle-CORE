# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      # GET /api/v4/endpoints -- endpoint discovery/index. The route the OpenAPI
      # document describes as getEndpoints; without it the documented operation
      # would 404.
      class StoredFilterIndexTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          @user = User.find_by(email: 'guest@datacycle.at')
          @user.update!(access_token: SecureRandom.hex) if @user.access_token.blank?

          @api_endpoint = DataCycleCore::StoredFilter.create!(
            name: 'endpoints index test',
            user_id: @user.id,
            api: true,
            parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Tour'] }]
          )
          @second_api_endpoint = DataCycleCore::StoredFilter.create!(
            name: 'endpoints index test (second)',
            user_id: @user.id,
            api: true,
            parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Tour'] }]
          )
          @non_api_endpoint = DataCycleCore::StoredFilter.create!(
            name: 'endpoints index test (non-api)',
            user_id: @user.id,
            api: false,
            parameters: [{ 'c' => 'd', 't' => 'template_names', 'v' => ['Tour'] }]
          )
        end

        test 'GET /api/v4/endpoints lists the api: true endpoints visible to the token owner' do
          get api_v4_endpoints_path, headers: { Authorization: "Bearer #{@user.access_token}" }

          assert_response :success
          assert_equal('application/json; charset=utf-8', response.content_type)
          json_data = response.parsed_body

          ids = json_data['@graph'].pluck('@id')

          assert_includes ids, @api_endpoint.id
          assert_not_includes ids, @non_api_endpoint.id

          entry = json_data['@graph'].find { |item| item['@id'] == @api_endpoint.id }

          assert_equal @api_endpoint.name, entry['name']
          assert_predicate entry['dc:entityUrl'], :present?
        end

        test 'GET /api/v4/endpoints without a token is unauthorized' do
          get api_v4_endpoints_path

          assert_response :unauthorized
        end

        # The action hands ApiBaseController#apply_paging a plain ActiveRecord::Relation, and
        # the page[limit] branch used to call #query on it - a Filter::QueryBuilder method that
        # a relation does not have, so the parameter the OpenAPI document advertises as
        # pageLimit answered with NoMethodError instead of a page.
        test 'GET /api/v4/endpoints supports page[limit] and page[offset]' do
          headers = { Authorization: "Bearer #{@user.access_token}" }

          get(api_v4_endpoints_path(page: { limit: 1 }), headers:)

          assert_response :success
          first_page = response.parsed_body['@graph'].pluck('@id')

          assert_equal 1, first_page.size

          get(api_v4_endpoints_path(page: { limit: 1, offset: 1 }), headers:)

          assert_response :success
          second_page = response.parsed_body['@graph'].pluck('@id')

          assert_equal 1, second_page.size
          assert_not_equal first_page, second_page
        end

        # The document advertises getEndpoints with LIST_PARAM_NAMES, so the contract has to
        # accept exactly those: anything narrower rejects a documented request, anything
        # wider (the catch-all ApiContract #validate_params_contract used to fall back to)
        # accepts filter/groupBy/MVT params the action silently ignores.
        DOCUMENTED_PARAM_VALUES = {
          'fields' => 'name',
          'include' => 'name',
          'classificationTrees' => 'b8e3b2a4-0000-4000-8000-000000000000',
          'language' => 'de',
          'sort' => 'name',
          'page[size]' => '1',
          'page[number]' => '1',
          'page[offset]' => '0',
          'page[limit]' => '1',
          'section[@graph]' => '1',
          'section[@context]' => '1',
          'section[meta]' => '1',
          'section[links]' => '1',
          'token' => nil # filled in per request from the signed-in user
        }.freeze

        test 'the documented getEndpoints parameters are exactly the ones covered here' do
          documented = DataCycleCore::OpenApi::Paths::Common::LIST_PARAM_NAMES.map do |name|
            DataCycleCore::OpenApi::Components::Parameters.all.fetch(name)['name']
          end

          assert_equal documented.sort, DOCUMENTED_PARAM_VALUES.keys.sort,
                       'a parameter was added to or removed from the document without revisiting the index contract'
        end

        test 'GET /api/v4/endpoints accepts every parameter the document advertises' do
          query = DOCUMENTED_PARAM_VALUES.merge('token' => @user.access_token)
            .map { |name, value| "#{name}=#{CGI.escape(value)}" }.join('&')

          get "#{api_v4_endpoints_path}?#{query}", headers: { Authorization: "Bearer #{@user.access_token}" }

          assert_response :success, "a documented parameter was rejected: #{response.body}"
        end

        # StoredFiltersController inherits ContentsController's permitted keys, so the
        # content-lookup params (uuids, external_keys, external_source_id) survive strong
        # params and reach the contract. Listing endpoints honours none of them: the
        # catch-all ApiContract accepted and silently dropped them, the list contract says so.
        test 'GET /api/v4/endpoints rejects a permitted parameter the document does not advertise' do
          get(api_v4_endpoints_path(uuids: 'b8e3b2a4-0000-4000-8000-000000000000'), headers: { Authorization: "Bearer #{@user.access_token}" })

          assert_response :bad_request
        end
      end
    end
  end
end
