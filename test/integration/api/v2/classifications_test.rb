# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Api
    module V2
      class ClassificationTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          @routes = Engine.routes
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'api for classification_trees is reachable' do
          get api_v2_classification_trees_path

          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data = JSON.parse(response.body)
          assert_equal(['data', 'links', 'meta'], json_data.keys.sort)
        end

        test 'api for specific classificaiton_trees' do
          classification_tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Inhaltstypen')
          get api_v2_classification_tree_path(classification_tree)

          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data = JSON.parse(response.body)
          assert_equal(classification_tree.id, json_data.dig('data', 'id'))
          assert_equal(classification_tree.name, json_data.dig('data', 'name'))
        end

        test 'list of classifications within a classification_tree' do
          classification_tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Inhaltstypen')
          get classifications_api_v2_classification_tree_path(classification_tree)

          assert_response(:success)
          assert_equal('application/json', response.content_type)
          json_data = JSON.parse(response.body)
          assert_equal({ 'total' => 47, 'pages' => 2 }, json_data.dig('meta'))
          assert_equal(25, json_data.dig('data').count)
        end
      end
    end
  end
end
