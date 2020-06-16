# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        module Extensions
          module Places
            class PoiDataTest < DataCycleCore::V4::Base
              setup do
                @content = DataCycleCore::V4::DummyDataHelper.create_data('poi')
              end

              test 'api_v4_thing_path validate full image with default params' do
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
                assert_attributes(json_validate, required_attributes, ['id', 'name']) do
                  {
                    '@id' => @content.id,
                    '@type' => 'ImageObject',
                    'name' => @content.title
                  }
                end

                # plain attributes without transformation
                assert_attributes(json_validate, required_attributes, ['description', 'url', 'caption', 'keywords', 'content_url', 'thumbnail_url', 'file_format', 'upload_date', 'content_size', 'copyright_year']) do
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
                    'sameAs' => @content.url
                  }
                end

                # plain attributes without transformation
                assert_attributes(json_validate, required_attributes, ['width', 'height']) do
                  {
                    'width' => {
                      '@type' => 'QuantitativeValue',
                      'identifier' => 'width',
                      'name' => 'Breite',
                      'unitCode' => 'E37',
                      'unitText' => 'pixel',
                      'value' => @content.width
                    },
                    'height' => {
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
                assert_equal({}, json_validate)
              end
            end
          end
        end
      end
    end
  end
end
