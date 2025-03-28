# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        module Extensions
          module Places
            class PoiDataTest < DataCycleCore::V4::Base
              include DataCycleCore::ApiHelper

              before(:all) do
                @content = DataCycleCore::V4::DummyDataHelper.create_data('full_poi')
              end

              test 'api_v4_thing_path validate full poi with default params' do
                assert_full_thing_datahash(@content)

                params = {
                  id: @content.id
                }
                post api_v4_thing_path(params)
                json_data = response.parsed_body
                json_validate = json_data.dup['@graph'].first

                assert_context(json_data['@context'], 'de')

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
                assert_attributes(json_validate, required_attributes, ['description', 'dc:slug']) do
                  {
                    'description' => @content.description,
                    'dc:slug' => @content.slug
                  }
                end

                # disabled attributes
                assert_attributes(json_validate, required_attributes, ['validity_period']) do
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

                # address
                assert_attributes(json_validate, required_attributes, ['address', 'contact_info']) do
                  {
                    'address' => {
                      '@id' => generate_uuid(@content.id, 'address'),
                      '@type' => 'PostalAddress',
                      'streetAddress' => @content.address.street_address,
                      'postalCode' => @content.address.postal_code,
                      'addressLocality' => @content.address.address_locality,
                      'addressCountry' => @content.country_code.first.classification_aliases.first.name,
                      'name' => @content.contact_info.contact_name,
                      'telephone' => @content.contact_info.telephone,
                      'faxNumber' => @content.contact_info.fax_number,
                      'email' => @content.contact_info.email,
                      'url' => @content.contact_info.url
                    }
                  }
                end

                # linked default: images, member
                assert_attributes(json_validate, required_attributes, ['image', 'logo', 'primary_image']) do
                  {
                    'image' => [
                      @content.image.first.to_api_default_values
                    ],
                    'logo' => [
                      @content.logo.first.to_api_default_values
                    ],
                    'photo' => [
                      @content.primary_image.first.to_api_default_values
                    ]
                  }
                end

                # linked default: images, member
                assert_attributes(json_validate, required_attributes, ['potential_action']) do
                  {
                    'potentialAction' => [
                      {
                        '@id' => @content.potential_action.first.id,
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

                assert_attributes(json_validate, required_attributes, ['opening_hours_specification', 'opening_hours_description']) do
                  {
                    'openingHoursSpecification' => [{
                      '@id' => @content.opening_hours_specification.find_by("dtstart <= '2019-10-10 10:00'").id,
                      '@type' => 'OpeningHoursSpecification',
                      'validFrom' => '2019-10-10',
                      'validThrough' => '2019-10-17',
                      'dayOfWeek' => ['https://schema.org/Monday'],
                      'opens' => '10:00',
                      'closes' => '11:00'
                    }, {
                      '@id' => @content.opening_hours_specification.find_by("dtstart >= '2019-10-10 10:00'").id,
                      '@type' => 'OpeningHoursSpecification',
                      'validFrom' => '2019-10-10',
                      'validThrough' => '2019-10-17',
                      'dayOfWeek' => ['https://schema.org/Monday'],
                      'opens' => '13:00',
                      'closes' => '14:00'
                    }, {
                      '@id' => @content.opening_hours_description.first.id,
                      '@type' => ['Intangible', 'StructuredValue', 'OpeningHoursSpecification', 'dcls:Öffnungszeit - Beschreibung'],
                      'validFrom' => '2019-10-10',
                      'description' => 'Description - Test',
                      'dc:multilingual' => false,
                      'dc:translation' => ['de']
                    }]
                  }
                end

                assert_attributes(json_validate, required_attributes, ['text', 'price_range', 'author', 'price', 'directions', 'parking', 'hours_available', 'feratel_content_score', 'content_score']) do
                  {
                    'additionalProperty' => [
                      {
                        '@id' => generate_uuid(@content.id, 'text'),
                        '@type' => 'PropertyValue',
                        'identifier' => 'text',
                        'name' => 'Beschreibung',
                        'value' => @content.text
                      },
                      {
                        '@id' => generate_uuid(@content.id, 'price_range'),
                        '@type' => 'PropertyValue',
                        'identifier' => 'priceRange',
                        'name' => 'Preis-Info',
                        'value' => @content.price_range
                      },
                      {
                        '@id' => generate_uuid(@content.id, 'author'),
                        '@type' => 'PropertyValue',
                        'identifier' => 'author',
                        'name' => 'Autor',
                        'value' => @content.author
                      },
                      {
                        '@id' => generate_uuid(@content.id, 'price'),
                        '@type' => 'PropertyValue',
                        'identifier' => 'price',
                        'name' => 'Preis',
                        'value' => @content.price
                      },
                      {
                        '@id' => generate_uuid(@content.id, 'directions'),
                        '@type' => 'PropertyValue',
                        'identifier' => 'directions',
                        'name' => 'Anfahrtsbeschreibung',
                        'value' => @content.directions
                      },
                      {
                        '@id' => generate_uuid(@content.id, 'parking'),
                        '@type' => 'PropertyValue',
                        'identifier' => 'parking',
                        'name' => 'Parkmöglichkeit',
                        'value' => @content.parking
                      },
                      {
                        '@id' => generate_uuid(@content.id, 'hours_available'),
                        '@type' => 'PropertyValue',
                        'identifier' => 'hoursAvailable',
                        'name' => 'Service-Zeiten',
                        'value' => @content.hours_available
                      },
                      {
                        '@id' => generate_uuid(@content.id, 'feratel_content_score'),
                        '@type' => 'PropertyValue',
                        'identifier' => 'feratelContentScore',
                        'name' => 'ContentScore (Feratel)',
                        'value' => @content.feratel_content_score
                      },
                      {
                        '@id' => generate_uuid(@content.id, 'content_score'),
                        '@type' => 'PropertyValue',
                        'identifier' => 'contentScore',
                        'name' => 'ContentScore',
                        'value' => @content.content_score
                      }
                    ]
                  }
                end

                assert_attributes(json_validate, required_attributes, ['location', 'latitude', 'longitude', 'elevation']) do
                  {
                    'geo' => {
                      '@id' => generate_uuid(@content.id, 'geo'),
                      '@type' => 'GeoCoordinates',
                      'longitude' => @content.longitude,
                      'latitude' => @content.latitude,
                      'elevation' => @content.elevation
                    }
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
