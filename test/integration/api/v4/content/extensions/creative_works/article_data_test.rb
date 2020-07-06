# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        module Extensions
          module CreativeWorks
            class ArticleDataTest < DataCycleCore::V4::Base
              setup do
                @content = DataCycleCore::V4::DummyDataHelper.create_data('article')
              end

              test 'api_v4_thing_path validate full person with default params' do
                assert_full_thing_datahash(@content)

                params = {
                  id: @content.id
                }
                post api_v4_thing_path(params)
                json_data = JSON.parse response.body
                json_validate = json_data.dup

                # validate context
                json_context = json_validate.delete('@context')
                assert_equal(2, json_context.size)
                assert_equal('http://schema.org', json_context.first)
                validator = DataCycleCore::V4::Validation::Context.context
                assert_equal({}, validator.call(json_context.second).errors.to_h)

                # test full event data
                required_attributes = required_validation_attributes(@content)
                # test minimal

                assert_attributes(json_validate, required_attributes, ['id', 'name', 'headline']) do
                  {
                    '@id' => @content.id,
                    '@type' => 'Article',
                    'name' => @content.name,
                    'headline' => @content.headline
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

                # plain attributes without transformation
                assert_attributes(json_validate, required_attributes, ['description', 'url', 'text', 'keywords', 'alternative_headline']) do
                  {
                    'description' => @content.description,
                    'sameAs' => @content.url,
                    'text' => @content.text,
                    'keywords' => @content.keywords,
                    'alternativeHeadline' => @content.alternative_headline
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
                    'cc:useGuidelines' => @content.use_guidelines,
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
                assert_attributes(json_validate, required_attributes, ['potential_action']) do
                  {
                    'potentialAction' => [
                      {
                        '@type' => 'Action',
                        'dc:multilingual' => true,
                        'dc:translation' => [
                          'de'
                        ],
                        'name' => @content.potential_action.first.name,
                        'url' => @content.potential_action.first.url
                      }
                    ]
                  }
                end

                # same_as => additionalProperty
                assert_attributes(json_validate, required_attributes, ['link_name']) do
                  {
                    'additionalProperty' => [
                      {
                        '@type' => 'PropertyValue',
                        'identifier' => 'linkName',
                        'value' => @content.link_name,
                        'name' => 'Linktitel'
                      }
                    ]
                  }
                end

                assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

                assert_equal([], required_attributes)
                assert_equal({}, json_validate)
              end
            end
          end
        end
      end
    end
  end
end
