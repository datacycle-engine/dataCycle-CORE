# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class ClassificationTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper

        def embedded_concept_attributes
          ['inScheme', 'topConceptOf', 'broader', 'ancestors']
        end

        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes
          @trees = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('api').count
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'api/v4/concept_schemes parameter filter[:created_since]' do
          get api_v4_concept_schemes_path(filter: { created_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(@trees, json_data['@graph'].size)
          assert_equal(@trees, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'api/v4/concept_schemes parameter filter[:modified_since]' do
          get api_v4_concept_schemes_path(filter: { modified_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(@trees, json_data['@graph'].size)
          assert_equal(@trees, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'api/v4/concept_schemes parameter filter[:deleted_since]' do
          get api_v4_concept_schemes_path(filter: { deleted_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(0, json_data['@graph'].size)
          assert_equal(0, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          DataCycleCore::MasterData::ImportClassifications.import_all(classification_paths: [Rails.root.join('..', 'dummy_data', 'classifications')])
          DataCycleCore::ClassificationTreeLabel.find_by(name: 'Test').destroy

          get api_v4_concept_schemes_path(filter: { deleted_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'api/v4/concept_schemes/id/concepts parameter filter[:created_since]' do
          tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
          classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
          get classifications_api_v4_concept_scheme_path(id: tree_id, filter: { created_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(classifications, json_data['@graph'].size)
          assert_equal(classifications, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'api/v4/concept_schemes/id/concepts parameter filter[:modified_since]' do
          tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
          classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
          get classifications_api_v4_concept_scheme_path(id: tree_id, filter: { modified_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(classifications, json_data['@graph'].size)
          assert_equal(classifications, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'api/v4/concept_schemes/id/concepts parameter filter[:deleted_since]' do
          DataCycleCore::MasterData::ImportClassifications.import_all(classification_paths: [Rails.root.join('..', 'dummy_data', 'classifications')])
          tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Test').id
          classifications = DataCycleCore::ClassificationAlias.for_tree('Test').count

          get classifications_api_v4_concept_scheme_path(id: tree_id, filter: { deleted_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(0, json_data['@graph'].size)
          assert_equal(0, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          DataCycleCore::ClassificationAlias.for_tree('Test').destroy_all
          get classifications_api_v4_concept_scheme_path(id: tree_id, filter: { deleted_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(classifications, json_data['@graph'].size)
          assert_equal(classifications, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end
      end
    end
  end
end
