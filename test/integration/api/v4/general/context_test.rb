# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module General
        class ContextTest < DataCycleCore::V4::Base
          setup do
            DataCycleCore::Thing.where(template: false).delete_all
          end

          test 'api/v4/concept_schemes' do
            post api_v4_concept_schemes_path

            json_data = JSON.parse(response.body)
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end

          test 'api/v4/concept_schemes with language de' do
            params = {
              language: 'de'
            }
            post api_v4_concept_schemes_path(params)

            json_data = JSON.parse(response.body)
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end

          test 'api/v4/concept_schemes with language en' do
            params = {
              language: 'en'
            }
            post api_v4_concept_schemes_path(params)

            json_data = JSON.parse(response.body)
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end

          test 'api/v4/concept_schemes with language it' do
            params = {
              language: 'it'
            }
            post api_v4_concept_schemes_path(params)

            json_data = JSON.parse(response.body)
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end

          test 'api/v4/concept_schemes with language de,en,it' do
            params = {
              language: 'de,en,it'
            }
            post api_v4_concept_schemes_path(params)

            json_data = JSON.parse(response.body)
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end
        end
      end
    end
  end
end