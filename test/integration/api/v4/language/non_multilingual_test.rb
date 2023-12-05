# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Language
        class NonMultilingualTest < DataCycleCore::V4::Base
          include DataCycleCore::ApiHelper
          # Testing not mulitlingual thing (Article)
          # only available in language de
          before(:all) do
            @content = DataCycleCore::V4::DummyDataHelper.create_data('structured_article')

            # add translation for author
            author = @content.author.first
            data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person_en')
            I18n.with_locale(:en) { author.set_data_hash(data_hash: author.get_data_hash.except(*author.computed_property_names).merge(data_hash_en)) }
            author.reload

            assert_full_thing_datahash(@content)
          end

          test 'non multilingual api_v4_thing_path, params: language:en' do
            params = {
              id: @content.id,
              language: 'en'
            }
            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), params.dig(:language))

            # empty because not exist in en
            required_attributes = []

            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type,
                'dc:multilingual' => false,
                'dc:translation' => [
                  'de'
                ]
              }
            end

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end

          test 'non multilingual api_v4_thing_path, params: language:de,en' do
            params = {
              id: @content.id,
              language: 'de,en'
            }
            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), params.dig(:language))

            required_attributes = required_validation_attributes(@content)

            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type,
                'dc:multilingual' => false,
                'dc:translation' => [
                  'de'
                ]
              }
            end

            # plain attributes without transformation
            assert_translated_attributes(json_validate, required_attributes, ['name', 'description', 'use_guidelines', 'text', 'url', 'text', 'keywords', 'headline', 'alternative_headline', 'dc:slug']) do
              {
                'name' => translated_value(@content, 'name', ['de']),
                'headline' => translated_value(@content, 'headline', ['de']),
                'description' => translated_value(@content, 'description', ['de']),
                'text' => translated_value(@content, 'text', ['de']),
                'keywords' => translated_value(@content, 'keywords', ['de']),
                'sameAs' => translated_value(@content, 'url', ['de']),
                'alternativeHeadline' => translated_value(@content, 'alternative_headline', ['de']),
                'cc:useGuidelines' => translated_value(@content, 'use_guidelines', ['de']),
                'dc:slug' => translated_value(@content, 'slug', ['de'])
              }
            end

            # disabled attributes
            assert_attributes(json_validate, required_attributes, ['validity_period', 'internal_name']) do
              {}
            end

            # cc_rel
            assert_attributes(json_validate, required_attributes, ['url', 'license', 'attribution_url', 'attribution_name', 'license_classification']) do
              # license is overwritten by license_classification
              {
                'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
                'url' => @content.attribution_url,
                'copyrightNotice' => @content.copyright_notice_computed
              }
            end

            # linked default
            assert_attributes(json_validate, required_attributes, ['image', 'content_location', 'author', 'video', 'content_block']) do
              {
                'author' => [
                  @content.author.first.to_api_default_values
                ],
                'contentBlock' => [
                  @content.content_block.first.to_api_default_values
                ],
                'contentLocation' => [
                  @content.content_location.first.to_api_default_values
                ],
                'image' => [
                  @content.image.first.to_api_default_values
                ],
                'video' => [
                  @content.video.first.to_api_default_values
                ]
              }
            end

            # potentialAction
            assert_translated_attributes(json_validate, required_attributes, ['potential_action']) do
              {
                'potentialAction' => [
                  {
                    '@id' => @content.potential_action.first.id,
                    '@type' => @content.potential_action.first.api_type,
                    'dc:multilingual' => true,
                    'dc:translation' => [
                      'de'
                    ],
                    'name' => translated_value(@content, 'potential_action.first.name', ['de']),
                    'url' => translated_value(@content, 'potential_action.first.url', ['de'])
                  }
                ]
              }
            end

            # additionalProperty
            assert_translated_attributes(json_validate, required_attributes, ['link_name']) do
              {
                'additionalProperty' => [
                  {
                    '@id' => generate_uuid(@content.id, 'link_name'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'linkName',
                    'value' => translated_value(@content, 'link_name', ['de']),
                    'name' => 'Linktitel'
                  }
                ]
              }
            end

            assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end

          test 'non multilingual api_v4_thing_path, params: language:de,en include translated and not translated linked object' do
            fields = [
              'name',
              'dc:multilingual',
              'dc:translation',
              'author.name',
              'author.jobTitle',
              'author.dc:multilingual',
              'author.dc:translation',
              'image.name',
              'image.dc:multilingual',
              'image.dc:translation'
            ]

            params = {
              id: @content.id,
              language: 'de,en',
              fields: fields.join(',')
            }
            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), params.dig(:language))

            # empty because of fields param
            required_attributes = []

            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type,
                'dc:multilingual' => false,
                'dc:translation' => [
                  'de'
                ]
              }
            end

            # plain attributes without transformation
            assert_translated_attributes(json_validate, required_attributes, ['name']) do
              {
                'name' => translated_value(@content, 'name', ['de'])
              }
            end

            # not translated image object
            assert_translated_attributes(json_validate, required_attributes, ['image']) do
              {
                'image' => [
                  @content.image.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de'
                      ],
                      'name' => translated_value(@content, 'image.first.name', ['de'])
                    }
                  )
                ]
              }
            end

            # translated author object
            assert_translated_attributes(json_validate, required_attributes, ['author']) do
              {
                'author' => [
                  @content.author.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => true,
                      'dc:translation' => [
                        'de',
                        'en'
                      ],
                      'name' => translated_value(@content, 'author.first.name', ['de', 'en']),
                      'jobTitle' => translated_value(@content, 'author.first.job_title', ['de', 'en'])
                    }
                  )
                ]
              }
            end

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end

          test 'non multilingual api_v4_thing_path, params: language:de,en include embedded object' do
            params = {
              id: @content.id,
              language: 'de,en',
              include: 'contentBlock'
            }
            post api_v4_thing_path(params)
            json_data = response.parsed_body
            json_validate = json_data.dup.dig('@graph').first

            assert_context(json_data.dig('@context'), params.dig(:language))

            required_attributes = required_validation_attributes(@content)

            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => @content.api_type,
                'dc:multilingual' => false,
                'dc:translation' => [
                  'de'
                ]
              }
            end

            # plain attributes without transformation
            assert_translated_attributes(json_validate, required_attributes, ['name', 'description', 'use_guidelines', 'text', 'url', 'text', 'keywords', 'headline', 'alternative_headline', 'dc:slug']) do
              {
                'name' => translated_value(@content, 'name', ['de']),
                'headline' => translated_value(@content, 'headline', ['de']),
                'description' => translated_value(@content, 'description', ['de']),
                'text' => translated_value(@content, 'text', ['de']),
                'keywords' => translated_value(@content, 'keywords', ['de']),
                'sameAs' => translated_value(@content, 'url', ['de']),
                'alternativeHeadline' => translated_value(@content, 'alternative_headline', ['de']),
                'cc:useGuidelines' => translated_value(@content, 'use_guidelines', ['de']),
                'dc:slug' => translated_value(@content, 'slug', ['de'])
              }
            end

            # disabled attributes
            assert_attributes(json_validate, required_attributes, ['validity_period', 'internal_name']) do
              {}
            end

            # cc_rel
            assert_attributes(json_validate, required_attributes, ['url', 'license', 'attribution_url', 'attribution_name', 'license_classification']) do
              # license is overwritten by license_classification
              {
                'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
                'url' => @content.attribution_url,
                'copyrightNotice' => @content.copyright_notice_computed
              }
            end

            # linked default
            assert_attributes(json_validate, required_attributes, ['image', 'content_location', 'author', 'video']) do
              {
                'author' => [
                  @content.author.first.to_api_default_values
                ],
                'contentLocation' => [
                  @content.content_location.first.to_api_default_values
                ],
                'image' => [
                  @content.image.first.to_api_default_values
                ],
                'video' => [
                  @content.video.first.to_api_default_values
                ]
              }
            end

            # potentialAction
            assert_translated_attributes(json_validate, required_attributes, ['potential_action']) do
              {
                'potentialAction' => [
                  {
                    '@id' => @content.potential_action.first.id,
                    '@type' => @content.potential_action.first.api_type,
                    'dc:multilingual' => true,
                    'dc:translation' => [
                      'de'
                    ],
                    'name' => translated_value(@content, 'potential_action.first.name', ['de']),
                    'url' => translated_value(@content, 'potential_action.first.url', ['de'])
                  }
                ]
              }
            end

            # additionalProperty
            assert_translated_attributes(json_validate, required_attributes, ['link_name']) do
              {
                'additionalProperty' => [
                  {
                    '@id' => generate_uuid(@content.id, 'link_name'),
                    '@type' => 'PropertyValue',
                    'identifier' => 'linkName',
                    'value' => translated_value(@content, 'link_name', ['de']),
                    'name' => 'Linktitel'
                  }
                ]
              }
            end

            assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

            # embedded
            assert_attributes(json_validate, required_attributes, ['content_block']) do
              {
                'contentBlock' => [
                  @content.content_block.first.to_api_default_values.merge(
                    {
                      'dc:multilingual' => false,
                      'dc:translation' => [
                        'de'
                      ],
                      'name' => translated_value(@content, 'content_block.first.name', ['de']),
                      'alternativeHeadline' => translated_value(@content, 'content_block.first.alternative_headline', ['de']),
                      'text' => translated_value(@content, 'content_block.first.text', ['de']),
                      'image' => [
                        @content.content_block.first.image.first.to_api_default_values
                      ]
                    }
                  )
                ]
              }
            end

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end
        end
      end
    end
  end
end
