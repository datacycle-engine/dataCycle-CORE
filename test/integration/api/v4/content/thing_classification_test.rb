# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class ThingClassificationTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper

        def embedded_concept_attributes
          ['inScheme', 'topConceptOf', 'broader', 'ancestors']
        end

        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes
          @content = DataCycleCore::DummyDataHelper.create_data('poi')
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'concepts at /api/v4/things/:id serializes with only minimal header' do
          get api_v4_thing_path(id: @content.id)
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@content)
          assert_equal(header, data)

          assert_compact_classification_header(json_data.dig('concepts'))
        end

        test 'concepts at /api/v4/things/:id with include concepts --> full data' do
          get api_v4_thing_path(id: @content.id, include: 'concepts')
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@content)
          assert_equal(header, data)

          assert_concept_attributes(json_data.dig('concepts', 0))
          json_data.dig('concepts', 0).slice(*embedded_concept_attributes).each do |embedded_attribute|
            assert_compact_classification_header(Array(json_data.dig('concepts', 0, embedded_attribute)))
          end
        end

        test 'concepts at /api/v4/things/:id with include concepts,concepts.inScheme' do
          get api_v4_thing_path(id: @content.id, include: 'concepts,concepts.inScheme')
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@content)
          assert_equal(header, data)

          assert_concept_attributes(json_data.dig('concepts', 0))
          json_data.dig('concepts', 0).slice(*embedded_concept_attributes).each do |embedded_attribute|
            assert_compact_classification_header(Array(json_data.dig('concepts', 0, embedded_attribute)))
          end

          assert_concept_attributes(json_data.dig('concepts', 0, 'inScheme'))
        end

        test 'include concepts,concepts.inScheme is equal to include concepts.inScheme' do
          get api_v4_thing_path(id: @content.id, include: 'concepts,concepts.inScheme')
          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          get api_v4_thing_path(id: @content.id, include: 'concepts.inScheme')
          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data2 = JSON.parse response.body
          assert_equal(json_data, json_data2)
        end

        test 'concepts at /api/v4/things/:id with fields concepts.inScheme.identifier' do
          get api_v4_thing_path(id: @content.id, fields: 'concepts.inScheme.identifier')
          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          assert_equal(['concepts'], json_data.keys)
          assert_equal(1, json_data.dig('concepts').size)
          assert_equal(['inScheme'], json_data.dig('concepts', 0).keys)
          assert_equal(['identifier'], json_data.dig('concepts', 0, 'inScheme').keys)
        end

        test 'combo if fields, include' do
          get api_v4_thing_path(id: @content.id, fields: 'concepts.inScheme.identifier', include: 'concepts')
          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          assert_equal(['concepts'], json_data.keys)
          assert_equal(1, json_data.dig('concepts').size)
          assert_concept_attributes(json_data.dig('concepts', 0))
          json_data.dig('concepts', 0).slice(*embedded_concept_attributes).each do |embedded_attribute|
            assert_compact_classification_header(Array(json_data.dig('concepts', 0, embedded_attribute)))
          end
          assert_equal(['identifier'], json_data.dig('concepts', 0, 'inScheme').keys)
        end

        test 'parameter filter[:concepts]' do
          get api_v4_things_path(filter: { concepts: [@content.country_code.first.classification_aliases.first.id] })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(true, json_data['links'].present?)
        end
      end
    end
  end
end