# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class ContainerTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper

        setup do
          @routes = Engine.routes
          @article = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'LifeCycleTestArtikel' })
          @container = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: { name: 'TestContainer' })
          sign_in(User.find_by(email: 'tester@datacycle.at'))
          @article.is_part_of = @container.id
          @article.set_data_hash(data_hash: { name: name }, prevent_history: true)
          @article.save
        end

        test 'container at /api/v4/things/:id serializes with attribute hasPart' do
          get api_v4_thing_path(id: @container.id)
          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@container)
          assert_equal(header, data)
          assert_compact_header(json_data.dig('hasPart'))
        end

        test 'container expands with include=hasPart ' do
          get api_v4_thing_path(id: @container.id, include: 'hasPart')
          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@container)
          assert_equal(header, data)

          header = json_data.dig('hasPart', 0).slice(*full_header_attributes)
          data = full_header_data(@article)
          assert_equal(header, data)
        end
      end
    end
  end
end