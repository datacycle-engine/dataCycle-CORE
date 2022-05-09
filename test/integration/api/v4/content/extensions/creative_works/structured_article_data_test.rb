# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        module Extensions
          module CreativeWorks
            class StructuredArticleDataTest < DataCycleCore::V4::Base
              before(:all) do
                @content = DataCycleCore::V4::DummyDataHelper.create_data('structured_article')
                assert_full_thing_datahash(@content)
              end

              test 'api_v4_thing_path structured_article' do
                params = {
                  id: @content.id
                }
                post api_v4_thing_path(params)
                json_data = JSON.parse response.body
                json_validate = json_data.dup.dig('@graph').first

                assert_context(json_data.dig('@context'), 'de')

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
                assert_attributes(json_validate, required_attributes, ['name', 'headline', 'description', 'url', 'text', 'keywords', 'alternative_headline', 'dc:slug']) do
                  {
                    'name' => @content.name,
                    'headline' => @content.headline,
                    'description' => @content.description,
                    'sameAs' => @content.url,
                    'text' => @content.text,
                    'keywords' => @content.keywords,
                    'alternativeHeadline' => @content.alternative_headline,
                    'dc:slug' => @content.slug
                  }
                end

                # disabled attributes
                assert_attributes(json_validate, required_attributes, ['validity_period', 'internal_name']) do
                  {}
                end

                # cc_rel
                assert_attributes(json_validate, required_attributes, ['url', 'license', 'use_guidelines', 'attribution_url', 'attribution_name', 'license_classification']) do
                  # license is overwritten by license_classification
                  {
                    'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
                    'cc:useGuidelines' => @content.use_guidelines,
                    'url' => @content.attribution_url,
                    'copyrightNotice' => @content.copyright_notice_computed
                  }
                end

                # linked
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
                assert_attributes(json_validate, required_attributes, ['potential_action']) do
                  {
                    'potentialAction' => [
                      {
                        '@type' => @content.potential_action.first.api_type,
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

                # additionalProperty
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

                # embedded
                assert_attributes(json_validate, required_attributes, ['content_block']) do
                  {
                    'contentBlock' => [
                      @content.content_block.first.to_api_default_values
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
