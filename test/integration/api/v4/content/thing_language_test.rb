# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
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
          get api_v4_thing_path(id: @content.id, language: 'de,en')
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse response.body

          assert_equal(['@context', '@graph'], json_data.keys.sort)
          header = json_data.dig('@graph', 0).slice(*full_header_attributes)
          data = full_header_data(@content)
          assert_equal(header, data)
          assert_compact_header(json_data.dig('@graph', 0, 'dc:classification'))
          assert_equal('de', json_data.dig('@graph', 0, '@language'))
          assert_equal('Test-POI', json_data.dig('@graph', 0, 'name'))

          assert_equal(['@context', '@graph'], json_data.keys.sort)
          header = json_data.dig('@graph', 1).slice(*full_header_attributes)
          data = I18n.with_locale(:en) { full_header_data(@content) }
          assert_equal(header, data)
          assert_compact_header(json_data.dig('@graph', 1, 'dc:classification'))
          assert_equal('en', json_data.dig('@graph', 1, '@language'))
          assert_equal('Test-POI-en', json_data.dig('@graph', 1, 'name'))
        end
      end
    end
  end
end
