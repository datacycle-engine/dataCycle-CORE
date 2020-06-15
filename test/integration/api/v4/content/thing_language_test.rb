# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module Content
        class ThingLanguageTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers
          include DataCycleCore::ApiV4Helper

          def embedded_concept_attributes
            ['skos:inScheme', 'skos:topConceptOf', 'skos:broader', 'skos:ancestors']
          end

          setup do
            DataCycleCore::Thing.where(template: false).delete_all
            @routes = Engine.routes
            @content = DataCycleCore::DummyDataHelper.create_data('poi_translated')
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'concepts at /api/v4/things/:id serializes with only minimal header, in de and en' do
            languages = 'de,en'
            get api_v4_thing_path(id: @content.id, language: languages)
            assert_response :success

            assert_equal(response.content_type, 'application/json')
            json_data = JSON.parse response.body

            header = json_data.slice(*full_header_attributes)
            data = full_header_data(@content, languages)
            assert_equal(header.except('name'), data.except('name'))
            assert_compact_classification_header(json_data.dig('dc:classification'))
            assert_equal(['de', 'en'], json_data.dig('name').map { |item| item.dig('@language') }.sort)
            assert_equal(['Test-POI', 'Test-POI-en'], json_data.dig('name').map { |item| item.dig('@value') }.sort)
          end
        end
      end
    end
  end
end
