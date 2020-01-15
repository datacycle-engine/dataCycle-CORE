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
          @tree = DataCycleCore::ClassificationTreeLabel.where(name: 'Geschlecht').visible('api').first
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
          assert_equal(true, json_data.key?('links'))
        end

        test 'api/v4/concept_schemes for :en (exists als available_locales)' do
          get api_v4_concept_schemes_path(language: 'en', fields: 'skos:prefLabel')
          assert_response :success
          json_data = JSON.parse(response.body)
          assert_equal('en', json_data.dig('@context', 1, '@language'))
          assert_equal('de', json_data.dig('@graph', 0, 'skos:prefLabel', 0, '@language'))
        end

        test 'api/v4/concept_schemes for :it (not in available_locales) defaulting to :de' do
          get api_v4_concept_schemes_path(language: 'it', fields: 'skos:prefLabel')
          assert_response :success
          json_data = JSON.parse(response.body)
          assert_equal('de', json_data.dig('@context', 1, '@language'))
          assert_equal(::String, json_data.dig('@graph', 0, 'skos:prefLabel').class)
        end

        test 'api/v4/concept_schemes test multilingual en,it,de -> selects only de' do
          get api_v4_concept_schemes_path(language: 'en,it,de', fields: 'skos:prefLabel')
          assert_response :success
          json_data = JSON.parse(response.body)
          assert_nil(json_data.dig('@context', 1, '@language'))
          assert_equal('de', json_data.dig('@graph', 0, 'skos:prefLabel', 0, '@language'))
        end

        test 'api/v4/concept_schemes/:id/concepts -> selects only de' do
          get classifications_api_v4_concept_scheme_path(id: @tree.id, params: { language: 'en,it,de', fields: 'skos:prefLabel' })
          assert_response :success
          json_data = JSON.parse(response.body)
          assert_nil(json_data.dig('@context', 1, '@language'))
          assert_equal('de', json_data.dig('@graph', 0, 'skos:prefLabel', 0, '@language'))
          assert_equal(@tree.classification_aliases.count, json_data.dig('meta', 'total').to_i)
        end

        test 'api/v4/concept_schemes/:id/concepts -> no language within available_locales -> fallback: de' do
          get classifications_api_v4_concept_scheme_path(id: @tree.id, params: { language: 'ug,li', fields: 'skos:prefLabel' })
          assert_response :success
          json_data = JSON.parse(response.body)
          assert_equal('de', json_data.dig('@context', 1, '@language'))
          assert_equal(::String, json_data.dig('@graph', 0, 'skos:prefLabel').class)
          assert_equal(@tree.classification_aliases.count, json_data.dig('meta', 'total').to_i)
        end
      end
    end
  end
end
