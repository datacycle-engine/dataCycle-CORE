# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'v4/validation/concept'
require 'v4/helpers/api_helper'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationLanguageTest < ActionDispatch::IntegrationTest
          include Devise::Test::IntegrationHelpers
          include Engine.routes.url_helpers
          include DataCycleCore::V4::ApiHelper

          setup do
            @routes = Engine.routes
            @tree = DataCycleCore::ClassificationTreeLabel.where(name: 'Tags').visible('api').first
            @trees = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('api').count

            # add translation
            @classification_tag = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 2').first
            I18n.with_locale(:en) do
              @classification_tag.attributes = {
                name: 'Tag 2 - EN',
                description: 'Tag 2 - Description'
              }
            end
            @classification_tag.save
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          # teardown do
          #   I18n.with_locale(:en) do
          #     @classificaton_tag.attributes = {
          #       name: nil,
          #       description: nil
          #     }
          #   end
          #   @classificaton_tag.save
          #   binding.pry
          # end

          test 'api/v4/concept_schemes exists in language: de' do
            params = {
              language: 'de'
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_equal('de', json_data.dig('@context', 1, '@language'))

            validator = DataCycleCore::V4::Validation::Concept.concept_scheme
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes for :en (exists als available_locales)' do
            params = {
              language: 'en',
              fields: 'skos:prefLabel'
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_equal('en', json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array).each do
                hash do
                  required(:'@language').value(eql?: 'de')
                  required(:'@value').value(:string)
                end
              end
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes for :it (not in available_locales) defaulting to :de' do
            params = {
              language: 'it',
              fields: 'skos:prefLabel'
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_equal('de', json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes test multilingual en,it,de -> selects only de' do
            params = {
              language: 'en,it,de',
              fields: 'skos:prefLabel'
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_nil(json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array).each do
                hash do
                  required(:'@language').value(eql?: 'de')
                  required(:'@value').value(:string)
                end
              end
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/:id/concepts -> selects only de' do
            params = {
              id: @tree.id,
              language: 'de',
              fields: 'skos:prefLabel,dct:description'
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = JSON.parse(response.body)
            assert_equal('de', json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              optional(:'dct:description').value(:string)
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/:id/concepts -> no language within available_locales -> fallback: de' do
            params = {
              id: @tree.id,
              language: 'hu,ab',
              fields: 'skos:prefLabel,dct:description'
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = JSON.parse(response.body)
            assert_equal('de', json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              optional(:'dct:description').value(:string)
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/:id/concepts -> selects only en -> returns en widh de fallback' do
            params = {
              id: @tree.id,
              language: 'en',
              fields: 'skos:prefLabel,dct:description'
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = JSON.parse(response.body)
            assert_equal('en', json_data.dig('@context', 1, '@language'))

            fields_translated = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              optional(:'dct:description').value(:string)
            end

            fields_fallback = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array).each do
                hash do
                  required(:'@language').value(eql?: 'de')
                  required(:'@value').value(:string)
                end
              end
              optional(:'dct:description').value(:array).each do
                hash do
                  required(:'@language').value(eql?: 'de')
                  required(:'@value').value(:string)
                end
              end
            end

            validator_translated = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields_translated })
            validator_fallback = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields_fallback })

            json_data['@graph'].each do |item|
              if @classification_tag.id == item.dig('@id')
                assert_equal({}, validator_translated.call(item).errors.to_h)
              else
                assert_equal({}, validator_fallback.call(item).errors.to_h)
              end
            end
          end

          test 'api/v4/concept_schemes/:id/concepts -> selects en,it -> returns en with de fallback' do
            params = {
              id: @tree.id,
              language: 'en,it',
              fields: 'skos:prefLabel,dct:description'
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = JSON.parse(response.body)
            assert_equal('en', json_data.dig('@context', 1, '@language'))

            fields_translated = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              optional(:'dct:description').value(:string)
            end

            fields_fallback = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array).each do
                hash do
                  required(:'@language').value(eql?: 'de')
                  required(:'@value').value(:string)
                end
              end
              optional(:'dct:description').value(:array).each do
                hash do
                  required(:'@language').value(eql?: 'de')
                  required(:'@value').value(:string)
                end
              end
            end

            validator_translated = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields_translated })
            validator_fallback = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields_fallback })

            json_data['@graph'].each do |item|
              if @classification_tag.id == item.dig('@id')
                assert_equal({}, validator_translated.call(item).errors.to_h)
              else
                assert_equal({}, validator_fallback.call(item).errors.to_h)
              end
            end
          end

          test 'api/v4/concept_schemes/:id/concepts -> selects en,de -> returns en and de' do
            params = {
              id: @tree.id,
              language: 'en,de',
              fields: 'skos:prefLabel,dct:description'
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = JSON.parse(response.body)
            assert_nil(json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array).each do
                hash do
                  required(:'@language') { eql?('de') | eql?('en') }
                  required(:'@value').value(:string)
                end
              end
              optional(:'dct:description').value(:array).each do
                hash do
                  required(:'@language') { eql?('de') | eql?('en') }
                  required(:'@value').value(:string)
                end
              end
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })

            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/:id/concepts -> selects en,it, de with nontranslatable attribute -> returns en and de' do
            params = {
              id: @tree.id,
              language: 'en,it,de',
              fields: 'skos:prefLabel,dct:description, dct:modified, skos:inScheme'
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = JSON.parse(response.body)
            assert_nil(json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array).each do
                hash do
                  required(:'@language') { eql?('de') | eql?('en') }
                  required(:'@value').value(:string)
                end
              end
              optional(:'dct:description').value(:array).each do
                hash do
                  required(:'@language') { eql?('de') | eql?('en') }
                  required(:'@value').value(:string)
                end
              end
              required(:'dct:modified').value(:date_time)
              required(:'skos:inScheme').hash(DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER)
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })

            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end
        end
      end
    end
  end
end