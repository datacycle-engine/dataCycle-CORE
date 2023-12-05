# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        module Extensions
          module MediaObjects
            class ImageDataTest < DataCycleCore::V4::Base
              include DataCycleCore::ApiHelper

              before(:all) do
                @content = DataCycleCore::V4::DummyDataHelper.create_data('full_image')
                @image_proxy_config = DataCycleCore.features[:image_proxy].deep_dup
              end

              test 'api_v4_thing_path validate full image with default params and enabled image proxy' do
                DataCycleCore.features[:image_proxy][:enabled] = true
                DataCycleCore::Feature::ImageProxy.reload
                assert DataCycleCore::Feature::ImageProxy.enabled?

                assert_full_thing_datahash(@content)

                params = {
                  id: @content.id
                }
                post api_v4_thing_path(params)
                json_data = response.parsed_body
                json_validate = json_data.dup.dig('@graph').first

                assert_context(json_data.dig('@context'), 'de')

                # test full event data
                required_attributes = required_validation_attributes(@content)
                # test minimal
                assert_attributes(json_validate, required_attributes, ['id', 'name']) do
                  {
                    '@id' => @content.id,
                    '@type' => @content.api_type,
                    'name' => @content.name
                  }
                end

                # validate language
                assert_attributes(json_validate, required_attributes, []) do
                  {
                    'dc:multilingual' => true,
                    'dc:translation' => [
                      'de'
                    ]
                  }
                end

                # plain attributes without transformation
                assert_attributes(json_validate, required_attributes, ['description', 'url', 'caption', 'keywords', 'content_url', 'thumbnail_url', 'file_format', 'upload_date', 'content_size', 'copyright_year', 'dc:slug']) do
                  {
                    'description' => @content.description,
                    'keywords' => @content.keywords,
                    'contentUrl' => DataCycleCore::Feature::ImageProxy.process_image(content: @content, variant: 'default'),
                    'thumbnailUrl' => DataCycleCore::Feature::ImageProxy.process_image(content: @content, variant: 'thumb'),
                    'dc:webUrl' => DataCycleCore::Feature::ImageProxy.process_image(content: @content, variant: 'web'),
                    'fileFormat' => @content.file_format,
                    'uploadDate' => @content.upload_date.as_json,
                    'contentSize' => @content.content_size,
                    'copyrightYear' => @content.copyright_year,
                    'caption' => @content.caption,
                    'sameAs' => @content.url,
                    'dc:slug' => @content.slug
                  }
                end

                # plain attributes with transformation
                assert_attributes(json_validate, required_attributes, ['width', 'height']) do
                  {
                    'width' => {
                      '@id' => generate_uuid(@content.id, 'width'),
                      '@type' => 'QuantitativeValue',
                      'identifier' => 'width',
                      'name' => 'Breite',
                      'unitCode' => 'E37',
                      'unitText' => 'pixel',
                      'value' => @content.width
                    },
                    'height' => {
                      '@id' => generate_uuid(@content.id, 'height'),
                      '@type' => 'QuantitativeValue',
                      'identifier' => 'height',
                      'name' => 'Höhe',
                      'unitCode' => 'E37',
                      'unitText' => 'pixel',
                      'value' => @content.height
                    }
                  }
                end

                # disabled attributes
                assert_attributes(json_validate, required_attributes, ['validity_period', 'alternative_headline']) do
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

                # linked default: images, member
                assert_attributes(json_validate, required_attributes, ['content_location', 'author', 'copyright_holder']) do
                  {
                    'contentLocation' => [
                      @content.content_location.first.to_api_default_values
                    ],
                    'author' => [
                      @content.author.first.to_api_default_values
                    ],
                    'copyrightHolder' => [
                      @content.copyright_holder.first.to_api_default_values
                    ]
                  }
                end

                assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

                assert_equal([], required_attributes)
                assert_equal({'mandatoryLicense' => false}, json_validate)
              end

              test 'api_v4_thing_path validate full image with default params and disabled image proxy' do
                DataCycleCore.features[:image_proxy][:enabled] = false
                DataCycleCore::Feature::ImageProxy.reload
                assert_not DataCycleCore::Feature::ImageProxy.enabled?

                assert_full_thing_datahash(@content)

                params = {
                  id: @content.id
                }
                post api_v4_thing_path(params)
                json_data = response.parsed_body
                json_validate = json_data.dup.dig('@graph').first

                assert_context(json_data.dig('@context'), 'de')

                # test full event data
                required_attributes = required_validation_attributes(@content)
                # test minimal
                assert_attributes(json_validate, required_attributes, ['id', 'name']) do
                  {
                    '@id' => @content.id,
                    '@type' => @content.api_type,
                    'name' => @content.name
                  }
                end

                # validate language
                assert_attributes(json_validate, required_attributes, []) do
                  {
                    'dc:multilingual' => true,
                    'dc:translation' => [
                      'de'
                    ]
                  }
                end

                # plain attributes without transformation
                assert_attributes(json_validate, required_attributes, ['description', 'url', 'caption', 'keywords', 'content_url', 'thumbnail_url', 'file_format', 'upload_date', 'content_size', 'copyright_year', 'dc:slug']) do
                  {
                    'description' => @content.description,
                    'keywords' => @content.keywords,
                    'contentUrl' => @content.content_url,
                    'thumbnailUrl' => @content.thumbnail_url,
                    'fileFormat' => @content.file_format,
                    'uploadDate' => @content.upload_date.as_json,
                    'contentSize' => @content.content_size,
                    'copyrightYear' => @content.copyright_year,
                    'caption' => @content.caption,
                    'sameAs' => @content.url,
                    'dc:slug' => @content.slug
                  }
                end

                # plain attributes with transformation
                assert_attributes(json_validate, required_attributes, ['width', 'height']) do
                  {
                    'width' => {
                      '@id' => generate_uuid(@content.id, 'width'),
                      '@type' => 'QuantitativeValue',
                      'identifier' => 'width',
                      'name' => 'Breite',
                      'unitCode' => 'E37',
                      'unitText' => 'pixel',
                      'value' => @content.width
                    },
                    'height' => {
                      '@id' => generate_uuid(@content.id, 'height'),
                      '@type' => 'QuantitativeValue',
                      'identifier' => 'height',
                      'name' => 'Höhe',
                      'unitCode' => 'E37',
                      'unitText' => 'pixel',
                      'value' => @content.height
                    }
                  }
                end

                # disabled attributes
                assert_attributes(json_validate, required_attributes, ['validity_period', 'alternative_headline']) do
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

                # linked default: images, member
                assert_attributes(json_validate, required_attributes, ['content_location', 'author', 'copyright_holder']) do
                  {
                    'contentLocation' => [
                      @content.content_location.first.to_api_default_values
                    ],
                    'author' => [
                      @content.author.first.to_api_default_values
                    ],
                    'copyrightHolder' => [
                      @content.copyright_holder.first.to_api_default_values
                    ]
                  }
                end

                assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

                assert_equal([], required_attributes)
                assert_equal({'mandatoryLicense' => false}, json_validate)
              end

              def teardown
                DataCycleCore.features[:image_proxy][:enabled] = @image_proxy_config[:enabled].dup
                DataCycleCore::Feature::ImageProxy.reload
              end
            end
          end
        end
      end
    end
  end
end
