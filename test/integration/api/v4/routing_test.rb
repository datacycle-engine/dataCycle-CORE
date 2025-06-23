# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      class RoutingTest < DataCycleCore::V4::Base
        before(:all) do
          @content = DataCycleCore::V4::DummyDataHelper.create_data('structured_article')
          @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').count
          @stored_filter = DataCycleCore::StoredFilter.create(
            name: 'all_items_filter',
            user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
            language: ['de'],
            api: true
          )
        end

        # only working in development and test environment
        test 'GET/POST /api/v4/things' do
          params = {}

          get api_v4_things_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(@thing_count)

          post api_v4_things_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(@thing_count)
        end

        test 'GET/POST /api/v4/things/:id' do
          params = {
            id: @content.id
          }

          get api_v4_thing_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_equal(@content.id, json_data['@graph'].first['@id'])

          post api_v4_thing_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_equal(@content.id, json_data['@graph'].first['@id'])
        end

        test 'GET/POST /api/v4/things/select' do
          params = {
            uuid: [
              @content.id,
              @content.image.first.id
            ]
          }

          get api_v4_contents_select_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(2)
          assert_equal([@content.id, @content.image.first.id].sort, json_data['@graph'].pluck('@id').sort)

          post api_v4_contents_select_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(2)
          assert_equal([@content.id, @content.image.first.id].sort, json_data['@graph'].pluck('@id').sort)

          params = {
            uuids: "#{@content.id},#{@content.image.first.id}"
          }
          get api_v4_contents_select_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(2)
          assert_equal([@content.id, @content.image.first.id].sort, json_data['@graph'].pluck('@id').sort)

          post api_v4_contents_select_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(2)
          assert_equal([@content.id, @content.image.first.id].sort, json_data['@graph'].pluck('@id').sort)
        end

        # test 'GET/POST /api/v4/endpoints/[:content_id(slug)]' do
        #   params = {
        #     content_id: @content.slug
        #   }
        #   get api_v4_stored_filter_path(id: @stored_filter.id), params: params, as: :json
        #   json_data = JSON.parse response.body
        #   assert_context(json_data.dig('@context'), 'de')
        #   assert_api_count_result(1)
        #   assert_equal([@content.id].sort, json_data['@graph'].map { |a| a['@id'] }.sort)
        #
        #   post api_v4_stored_filter_path(id: @stored_filter.id), params: params, as: :json
        #   json_data = JSON.parse response.body
        #   assert_context(json_data.dig('@context'), 'de')
        #   assert_api_count_result(1)
        #   assert_equal([@content.id].sort, json_data['@graph'].map { |a| a['@id'] }.sort)
        # end

        test 'GET/POST /api/v4/endpoints/[:content_id]' do
          params = {
            content_id: [
              @content.id,
              @content.image.first.id
            ]
          }

          get api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(2)
          assert_equal([@content.id, @content.image.first.id].sort, json_data['@graph'].pluck('@id').sort)

          post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(2)
          assert_equal([@content.id, @content.image.first.id].sort, json_data['@graph'].pluck('@id').sort)

          params = {
            content_id: @content.id
          }
          get api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(1)
          assert_equal([@content.id].sort, json_data['@graph'].pluck('@id').sort)

          post api_v4_stored_filter_path(id: @stored_filter.id), params:, as: :json
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(1)
          assert_equal([@content.id].sort, json_data['@graph'].pluck('@id').sort)
        end

        test 'GET/POST /api/v4/endpoints/things/[:content_id]' do
          params = {
            content_id: [
              @content.id,
              @content.image.first.id
            ]
          }

          get api_v4_stored_filter_things_path(id: @stored_filter.id), params:, as: :json
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(2)
          assert_equal([@content.id, @content.image.first.id].sort, json_data['@graph'].pluck('@id').sort)

          post api_v4_stored_filter_things_path(id: @stored_filter.id), params:, as: :json
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(2)
          assert_equal([@content.id, @content.image.first.id].sort, json_data['@graph'].pluck('@id').sort)

          params = {
            content_id: @content.id
          }
          get api_v4_stored_filter_things_path(id: @stored_filter.id), params:, as: :json
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(1)
          assert_equal([@content.id].sort, json_data['@graph'].pluck('@id').sort)

          post api_v4_stored_filter_things_path(id: @stored_filter.id), params:, as: :json
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_api_count_result(1)
          assert_equal([@content.id].sort, json_data['@graph'].pluck('@id').sort)
        end

        test '/api/v4/things/deleted' do
          deleted_content_id = @content.id
          @content.destroy_content
          params = {
            filter: {
              attribute: {
                'dct:deleted': {
                  in: {
                    min: '2010-01-01'
                  }
                }
              }
            }
          }
          get api_v4_contents_deleted_path(params)
          json_data = response.parsed_body
          assert_equal(2, json_data['@context'].size)
          assert_api_count_result(1)
          assert_equal(deleted_content_id, json_data['@graph'].first['@id'])
        end

        test 'GET/POST /api/v4/concept_schemes' do
          params = {}

          get api_v4_concept_schemes_path(params)
          assert_api_default_sections
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')

          post api_v4_concept_schemes_path(params)
          assert_api_default_sections
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
        end

        test 'GET/POST /api/v4/concept_schemes/id' do
          tree_id = DataCycleCore::ClassificationTreeLabel.where(name: 'Geschlecht').visible('api').first.id
          params = { id: tree_id }

          get api_v4_concept_scheme_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_equal(tree_id, json_data['@graph'].first['@id'])

          post api_v4_concept_scheme_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_equal(tree_id, json_data['@graph'].first['@id'])
        end

        test 'GET/POST /api/v4/concept_schemes/id/concepts' do
          tree_id = DataCycleCore::ClassificationTreeLabel.where(name: 'Geschlecht').visible('api').first.id
          params = { id: tree_id }

          get classifications_api_v4_concept_scheme_path(params)
          assert_api_default_sections
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')

          post classifications_api_v4_concept_scheme_path(params)
          assert_api_default_sections
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
        end

        test 'GET/POST /api/v4/concept_schemes/id/concepts/classification_id' do
          tree = DataCycleCore::ClassificationTreeLabel.all.detect { |item| DataCycleCore::ClassificationAlias.for_tree(item.name).any? }
          classification = DataCycleCore::ClassificationAlias.for_tree(tree.name).first
          params = {
            id: tree.id,
            classification_id: classification.id
          }

          get classifications_api_v4_concept_scheme_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_equal(classification.id, json_data['@graph'].first['@id'])

          post classifications_api_v4_concept_scheme_path(params)
          json_data = response.parsed_body
          assert_context(json_data['@context'], 'de')
          assert_equal(classification.id, json_data['@graph'].first['@id'])
        end

        test 'GET/POST /api/v4/users/:id' do
          user_id = User.find_by(email: 'tester@datacycle.at').id
          params = {
            id: user_id
          }
          get api_v4_users_user_path(params)
          json_data = response.parsed_body
          assert_equal(user_id, json_data['id'])

          post api_v4_users_user_path(params)
          json_data = response.parsed_body
          assert_equal(user_id, json_data['id'])
        end
      end
    end
  end
end
