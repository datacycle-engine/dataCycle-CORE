# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationLanguageTest < DataCycleCore::V4::Base
          before(:all) do
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
          end

          # TODO: add context test

          test 'api/v4/concept_schemes exists in language: de' do
            params = {
              language: 'de',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = response.parsed_body
            assert_equal('de', json_data.dig('@context', 1, '@language'))

            validator = DataCycleCore::V4::Validation::Concept.concept_scheme
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes for :en (exists als available_locales)' do
            params = {
              language: 'en',
              fields: 'skos:prefLabel',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = response.parsed_body
            assert_equal('en', json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array, min_size?: 1).each do
                hash do
                  required(:@language).value(eql?: 'de')
                  required(:@value).value(:string)
                end
              end
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes for :it (not in available_locales) defaulting to :de' do
            params = {
              language: 'it',
              fields: 'skos:prefLabel',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = response.parsed_body
            assert_equal('de', json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes test multilingual en,it,de -> selects only de' do
            params = {
              language: 'en,it,de',
              fields: 'skos:prefLabel',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = response.parsed_body
            assert_nil(json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array, min_size?: 1).each do
                hash do
                  required(:@language).value(eql?: 'de')
                  required(:@value).value(:string)
                end
              end
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/:id/concepts -> selects only de' do
            params = {
              id: @tree.id,
              language: 'de',
              fields: 'skos:prefLabel,dct:description',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = response.parsed_body
            assert_equal('de', json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              optional(:'dct:description').value(:string)
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/:id/concepts -> no language within available_locales -> fallback: de' do
            params = {
              id: @tree.id,
              language: 'hu,ab',
              fields: 'skos:prefLabel,dct:description',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = response.parsed_body
            assert_equal('de', json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              optional(:'dct:description').value(:string)
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          test 'api/v4/concept_schemes/:id/concepts -> selects only en -> returns en widh de fallback' do
            params = {
              id: @tree.id,
              language: 'en',
              fields: 'skos:prefLabel,dct:description',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = response.parsed_body
            assert_equal('en', json_data.dig('@context', 1, '@language'))

            fields_translated = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              optional(:'dct:description').value(:string)
            end

            fields_fallback = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array, min_size?: 1).each do
                hash do
                  required(:@language).value(eql?: 'de')
                  required(:@value).value(:string)
                end
              end
              optional(:'dct:description').value(:array, min_size?: 1).each do
                hash do
                  required(:@language).value(eql?: 'de')
                  required(:@value).value(:string)
                end
              end
            end

            validator_translated = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields_translated })
            validator_fallback = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields_fallback })
            concept_with_description = false
            json_data['@graph'].each do |item|
              if @classification_tag.id == item['@id']
                assert_equal({}, validator_translated.call(item).errors.to_h)
              else
                assert_equal({}, validator_fallback.call(item).errors.to_h)
              end
              # additional check to make sure at least one item has dct:description attribute
              concept_with_description = true if item['dct:description'].present?
            end
            assert(concept_with_description)
          end

          test 'api/v4/concept_schemes/:id/concepts -> selects en,it -> returns en with de fallback' do
            params = {
              id: @tree.id,
              language: 'en,it',
              fields: 'skos:prefLabel,dct:description',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = response.parsed_body
            assert_equal('en', json_data.dig('@context', 1, '@language'))

            fields_translated = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              optional(:'dct:description').value(:string)
            end

            fields_fallback = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array, min_size?: 1).each do
                hash do
                  required(:@language).value(eql?: 'de')
                  required(:@value).value(:string)
                end
              end
              optional(:'dct:description').value(:array, min_size?: 1).each do
                hash do
                  required(:@language).value(eql?: 'de')
                  required(:@value).value(:string)
                end
              end
            end

            validator_translated = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields_translated })
            validator_fallback = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields_fallback })

            concept_with_description = false
            json_data['@graph'].each do |item|
              if @classification_tag.id == item['@id']
                assert_equal({}, validator_translated.call(item).errors.to_h)
              else
                assert_equal({}, validator_fallback.call(item).errors.to_h)
              end
              # additional check to make sure at least one item has dct:description attribute
              concept_with_description = true if item['dct:description'].present?
            end
            assert(concept_with_description)
          end

          test 'api/v4/concept_schemes/:id/concepts -> selects en,de -> returns en and de' do
            params = {
              id: @tree.id,
              language: 'en,de',
              fields: 'skos:prefLabel,dct:description',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = response.parsed_body
            assert_nil(json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array, min_size?: 1).each do
                hash do
                  required(:@language) { eql?('de') | eql?('en') }
                  required(:@value).value(:string)
                end
              end
              optional(:'dct:description').value(:array, min_size?: 1).each do
                hash do
                  required(:@language) { eql?('de') | eql?('en') }
                  required(:@value).value(:string)
                end
              end
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })
            concept_with_description = false
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
              # additional check to make sure at least one item has dct:description attribute
              concept_with_description = true if item['dct:description'].present?
            end
            assert(concept_with_description)
          end

          test 'api/v4/concept_schemes/:id/concepts -> selects en,it, de with nontranslatable attribute -> returns en and de' do
            params = {
              id: @tree.id,
              language: 'en,it,de',
              fields: 'skos:prefLabel,dct:description, dct:modified, skos:inScheme',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(@tree.classification_aliases.count)

            json_data = response.parsed_body
            assert_nil(json_data.dig('@context', 1, '@language'))

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:array, min_size?: 1).each do
                hash do
                  required(:@language) { eql?('de') | eql?('en') }
                  required(:@value).value(:string)
                end
              end
              optional(:'dct:description').value(:array, min_size?: 1).each do
                hash do
                  required(:@language) { eql?('de') | eql?('en') }
                  required(:@value).value(:string)
                end
              end
              required(:'dct:modified').value(:date_time)
              required(:'skos:inScheme').hash(DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER)
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: })
            concept_with_description = false
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
              # additional check to make sure at least one item has dct:description attribute
              concept_with_description = true if item['dct:description'].present?
            end
            assert(concept_with_description)
          end
        end
      end
    end
  end
end
