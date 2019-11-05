# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      class ClassificationLanguageTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper

        def embedded_concept_attributes
          ['inScheme', 'topConceptOf', 'broader', 'ancestors']
        end

        setup do
          @routes = Engine.routes
          @trees = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('api').count
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'api/v4/concept_schemes exists in language: de' do
          get api_v4_concept_schemes_path(language: 'de')
          assert_response :success
          json_data = JSON.parse(response.body)

          assert_equal('de', json_data.dig('@context', 1, '@language'))
          assert_equal(@trees, json_data['@graph'].size)
          assert_equal(@trees, json_data['meta']['total'].to_i)
          assert_equal(true, json_data['links'].present?)
        end

        test 'api/v4/concept_schemes same fallback for :en and :it' do
          get api_v4_concept_schemes_path(language: 'en', fields: 'skos:prefLabel')
          assert_response :success
          json_data_en = JSON.parse(response.body)
          assert_equal('en', json_data_en.dig('@context', 1, '@language'))
          assert_equal('de', json_data_en.dig('@graph', 0, '@language'))

          get api_v4_concept_schemes_path(language: 'it', fields: 'skos:prefLabel')
          assert_response :success
          json_data_it = JSON.parse(response.body)
          assert_equal('it', json_data_it.dig('@context', 1, '@language'))
          assert_equal('de', json_data_en.dig('@graph', 0, '@language'))

          assert_equal(json_data_it.dig('@graph'), json_data_en.dig('@graph'))
        end

        test 'api/v4/concept_schemes test multilingual en,it,de -> selects only de' do
          get api_v4_concept_schemes_path(language: 'en,it,de', fields: 'skos:prefLabel')
          assert_response :success
          json_data_en = JSON.parse(response.body)
          assert_nil(json_data_en.dig('@context', 1, '@language'))
          assert_equal('de', json_data_en.dig('@graph', 0, '@language'))
        end
      end
    end
  end
end
