# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module Content
        class ThingLanguageTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          include DataCycleCore::ApiV4Helper

          def embedded_concept_attributes
            ['skos:inScheme', 'skos:topConceptOf', 'skos:broader', 'skos:ancestors']
          end

          before(:all) do
            DataCycleCore::Thing.delete_all
            @routes = Engine.routes
            @content = DataCycleCore::DummyDataHelper.create_data('poi_translated')
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'concepts at /api/v4/things/:id serializes with only minimal header, in de and en' do
            languages = 'de,en'
            get api_v4_thing_path(id: @content.id, language: languages)
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            header = json_data.slice(*full_header_attributes)
            data = full_header_data(@content, languages)
            assert_equal(header.except('name'), data.except('name'))
            assert_compact_classification_header(json_data['dc:classification'])
            assert_equal(['de', 'en'], json_data['name'].pluck('@language').sort)
            assert_equal(['Test-POI', 'Test-POI-en'], json_data['name'].pluck('@value').sort)
          end
        end
      end
    end
  end
end
