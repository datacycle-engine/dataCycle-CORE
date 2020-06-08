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
          ['skos:inScheme', 'skos:topConceptOf', 'skos:broader', 'skos:ancestors']
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

          assert_compact_classification_header(json_data.dig('dc:classification'))
        end

        test 'concepts at /api/v4/things/:id with include concepts --> full data' do
          get api_v4_thing_path(id: @content.id, include: 'dc:classification')
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@content)
          assert_equal(header, data)

          assert_concept_attributes(json_data.dig('dc:classification', 0))
          json_data.dig('dc:classification', 0).slice(*embedded_concept_attributes).each do |embedded_attribute|
            assert_compact_header(Array(json_data.dig('dc:classification', 0, embedded_attribute)))
          end
        end

        test 'concepts at /api/v4/things/:id with include dc:classification,dc:classification.skos:inScheme' do
          get api_v4_thing_path(id: @content.id, include: 'dc:classification,dc:classification.skos:inScheme')
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          header = json_data.slice(*full_header_attributes)
          data = full_header_data(@content)
          assert_equal(header, data)

          assert_concept_attributes(json_data.dig('dc:classification', 0))
          json_data.dig('dc:classification', 0).slice(*embedded_concept_attributes).each do |embedded_attribute|
            assert_compact_header(Array(json_data.dig('dc:classification', 0, embedded_attribute)))
          end

          assert_concept_attributes(json_data.dig('dc:classification', 0, 'skos:inScheme'))
        end

        test 'include dc:classification,dc:classification.skos:inScheme is equal to include dc:classification.skos:inScheme' do
          get api_v4_thing_path(id: @content.id, include: 'dc:classification,dc:classification.skos:inScheme')
          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          get api_v4_thing_path(id: @content.id, include: 'dc:classification.skos:inScheme')
          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data2 = JSON.parse response.body
          assert_equal(json_data, json_data2)
        end

        test 'concepts at /api/v4/things/:id with fields dc:classification.skos:inScheme.skos:prefLabel' do
          get api_v4_thing_path(id: @content.id, fields: 'dc:classification.skos:inScheme.skos:prefLabel')
          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          assert_equal(1, json_data.dig('dc:classification').size)
          assert_equal(['@id', '@type', 'skos:inScheme'], json_data.dig('dc:classification', 0).keys)
          assert_equal(['@id', '@type', 'skos:prefLabel'], json_data.dig('dc:classification', 0, 'skos:inScheme').keys)
        end

        test 'combo of fields, include' do
          get api_v4_thing_path(id: @content.id, fields: 'dc:classification.skos:inScheme.skos:prefLabel', include: 'dc:classification')
          assert_response :success
          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          assert_equal(1, json_data.dig('dc:classification').size)
          assert_concept_attributes(json_data.dig('dc:classification', 0))
          json_data.dig('dc:classification', 0).slice(*embedded_concept_attributes).each do |embedded_attribute|
            assert_compact_header(Array(json_data.dig('dc:classification', 0, embedded_attribute)))
          end
          assert_equal(['@id', '@type', 'skos:prefLabel'], json_data.dig('dc:classification', 0, 'skos:inScheme').keys)
        end
      end
    end
  end
end
