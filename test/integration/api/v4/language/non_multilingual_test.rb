# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Language
        class NonMultilingualTest < DataCycleCore::V4::Base
          setup do
            @content = DataCycleCore::V4::DummyDataHelper.create_data('structured_article')
            # add translation for image
            author = @content.author.first
            data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person_en')
            I18n.with_locale(:en) { author.set_data_hash(data_hash: author.get_data_hash.merge(data_hash_en)) }
            author.reload
          end

          test 'api_v4_thing_path validate non multilingual in en' do
            assert_full_thing_datahash(@content)

            params = {
              id: @content.id,
              language: 'en'
            }
            post api_v4_thing_path(params)
            json_data = JSON.parse response.body
            json_validate = json_data.dup

            # validate context
            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            # test full event data
            # empty because not exist in en
            required_attributes = []

            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => 'Article',
                'dc:multilingual' => false,
                'dc:translation' => [
                  'de'
                ]
              }
            end

            assert_equal([], required_attributes)
            assert_equal({}, json_validate)
          end

          test 'api_v4_thing_path validate non multilingual with language de,en' do
            assert_full_thing_datahash(@content)

            params = {
              id: @content.id,
              language: 'de,en'
            }
            post api_v4_thing_path(params)
            json_data = JSON.parse response.body
            json_validate = json_data.dup

            # validate context
            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            # test full event data

            # test full event data
            required_attributes = required_validation_attributes(@content)
            # test minimal

            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => 'Article'
              }
            end

            # plain attributes without transformation
            assert_translated_attributes(json_validate, required_attributes, ['name', 'description', 'use_guidelines', 'text', 'url', 'text', 'keywords', 'headline', 'alternative_headline']) do
              {
                'name' => translated_value(@content, 'name', ['de']),
                'headline' => translated_value(@content, 'headline', ['de']),
                'description' => translated_value(@content, 'description', ['de']),
                'text' => translated_value(@content, 'text', ['de']),
                'keywords' => translated_value(@content, 'keywords', ['de']),
                'sameAs' => translated_value(@content, 'url', ['de']),
                'alternativeHeadline' => translated_value(@content, 'alternative_headline', ['de']),
                'cc:useGuidelines' => translated_value(@content, 'use_guidelines', ['de'])
              }
            end

            # validate language
            assert_attributes(json_validate, required_attributes, []) do
              {
                'dc:multilingual' => false,
                'dc:translation' => [
                  'de'
                ]
              }
            end

            # disabled attributes
            assert_attributes(json_validate, required_attributes, ['validity_period', 'internal_name']) do
              {}
            end

            # cc_rel
            assert_attributes(json_validate, required_attributes, ['license', 'use_guidelines', 'attribution_url', 'attribution_name', 'more_permissions', 'license_classification']) do
              # license is overwritten by license_classification
              {
                'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
                'cc:attributionUrl' => @content.attribution_url,
                'cc:attributionName' => @content.attribution_name,
                'cc:morePermissions' => @content.more_permissions
              }
            end

            # linked default: images, member
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

            # linked default: images, member
            assert_translated_attributes(json_validate, required_attributes, ['potential_action']) do
              {
                'potentialAction' => [
                  {
                    '@type' => 'Action',
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

            # same_as => additionalProperty
            assert_translated_attributes(json_validate, required_attributes, ['link_name']) do
              {
                'additionalProperty' => [
                  {
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

          test 'api_v4_thing_path validate non multilingual with language de,en and include translated and not translated linked object' do
            assert_full_thing_datahash(@content)

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
            json_data = JSON.parse response.body
            json_validate = json_data.dup

            # validate context
            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            # empty because of fields param
            required_attributes = []

            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => 'Article'
              }
            end

            # plain attributes without transformation
            assert_translated_attributes(json_validate, required_attributes, ['name']) do
              {
                'name' => translated_value(@content, 'name', ['de'])
              }
            end

            # validate language
            assert_attributes(json_validate, required_attributes, []) do
              {
                'dc:multilingual' => false,
                'dc:translation' => [
                  'de'
                ]
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

          test 'api_v4_thing_path validate non multilingual with language de,en and include embedded object' do
            assert_full_thing_datahash(@content)

            params = {
              id: @content.id,
              language: 'de,en',
              include: 'contentBlock'
            }
            post api_v4_thing_path(params)
            json_data = JSON.parse response.body
            json_validate = json_data.dup

            # validate context
            json_context = json_validate.delete('@context')
            assert_equal(2, json_context.size)
            assert_equal('http://schema.org', json_context.first)
            validator = DataCycleCore::V4::Validation::Context.context(params.dig(:language))
            assert_equal({}, validator.call(json_context.second).errors.to_h)

            # test full event data

            # test full event data
            required_attributes = required_validation_attributes(@content)
            # test minimal

            assert_attributes(json_validate, required_attributes, ['id']) do
              {
                '@id' => @content.id,
                '@type' => 'Article'
              }
            end

            # plain attributes without transformation
            assert_translated_attributes(json_validate, required_attributes, ['name', 'description', 'use_guidelines', 'text', 'url', 'text', 'keywords', 'headline', 'alternative_headline']) do
              {
                'name' => translated_value(@content, 'name', ['de']),
                'headline' => translated_value(@content, 'headline', ['de']),
                'description' => translated_value(@content, 'description', ['de']),
                'text' => translated_value(@content, 'text', ['de']),
                'keywords' => translated_value(@content, 'keywords', ['de']),
                'sameAs' => translated_value(@content, 'url', ['de']),
                'alternativeHeadline' => translated_value(@content, 'alternative_headline', ['de']),
                'cc:useGuidelines' => translated_value(@content, 'use_guidelines', ['de'])
              }
            end

            # validate language
            assert_attributes(json_validate, required_attributes, []) do
              {
                'dc:multilingual' => false,
                'dc:translation' => [
                  'de'
                ]
              }
            end

            # disabled attributes
            assert_attributes(json_validate, required_attributes, ['validity_period', 'internal_name']) do
              {}
            end

            # cc_rel
            assert_attributes(json_validate, required_attributes, ['license', 'use_guidelines', 'attribution_url', 'attribution_name', 'more_permissions', 'license_classification']) do
              # license is overwritten by license_classification
              {
                'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
                'cc:attributionUrl' => @content.attribution_url,
                'cc:attributionName' => @content.attribution_name,
                'cc:morePermissions' => @content.more_permissions
              }
            end

            # linked default: images, member
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

            # linked default: images, member
            assert_translated_attributes(json_validate, required_attributes, ['potential_action']) do
              {
                'potentialAction' => [
                  {
                    '@type' => 'Action',
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

            # same_as => additionalProperty
            assert_translated_attributes(json_validate, required_attributes, ['link_name']) do
              {
                'additionalProperty' => [
                  {
                    '@type' => 'PropertyValue',
                    'identifier' => 'linkName',
                    'value' => translated_value(@content, 'link_name', ['de']),
                    'name' => 'Linktitel'
                  }
                ]
              }
            end

            assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

            # linked default: images, member
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
