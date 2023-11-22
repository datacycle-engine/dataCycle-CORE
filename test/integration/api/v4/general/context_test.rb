# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module General
        class ContextTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
          end

          test 'api/v4/concept_schemes' do
            post api_v4_concept_schemes_path

            json_data = response.parsed_body
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('https://schema.org/', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end

          test 'api/v4/concept_schemes with language de' do
            params = {
              language: 'de'
            }
            post api_v4_concept_schemes_path(params)

            json_data = response.parsed_body
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('https://schema.org/', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end

          test 'api/v4/concept_schemes with language en' do
            params = {
              language: 'en'
            }
            post api_v4_concept_schemes_path(params)

            json_data = response.parsed_body
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('https://schema.org/', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end

          test 'api/v4/concept_schemes with language it' do
            params = {
              language: 'it'
            }
            post api_v4_concept_schemes_path(params)

            json_data = response.parsed_body
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('https://schema.org/', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end

          test 'api/v4/concept_schemes with language de,en,it' do
            params = {
              language: 'de,en,it'
            }
            post api_v4_concept_schemes_path(params)

            json_data = response.parsed_body
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('https://schema.org/', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end

          test 'api/v4/things default paht' do
            params = {}
            post api_v4_things_path(params)

            json_data = response.parsed_body
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('https://schema.org/', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end

          test 'api/v4/things with fields: dct:modified' do
            params = {
              fields: 'dct:modified'
            }
            post api_v4_things_path(params)

            json_data = response.parsed_body
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('https://schema.org/', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end

          test 'api/v4/things/deleted with fields: dct:modified' do
            params = {}
            post api_v4_contents_deleted_path(params)

            json_data = response.parsed_body
            json_context = json_data.dig('@context')
            assert_equal(2, json_context.size)
            assert_equal('https://schema.org/', json_context.first)

            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)
          end
        end
      end
    end
  end
end
