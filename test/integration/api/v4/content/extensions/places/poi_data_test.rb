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
                @content = DataCycleCore::V4::DummyDataHelper.create_data('full_poi')
                @content.location = RGeo::Geographic.spherical_factory(srid: 4326).point(@content.longitude, @content.latitude)
                @content.save
              end

              test 'api_v4_thing_path validate full poi with default params' do
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
                    '@type' => 'TouristAttraction',
                    'name' => @content.name
                  }
                end

                # plain attributes without transformation
                assert_attributes(json_validate, required_attributes, ['description']) do
                  {
                    'description' => @content.description
                  }
                end

                # disabled attributes
                assert_attributes(json_validate, required_attributes, ['validity_period']) do
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

                # address
                assert_attributes(json_validate, required_attributes, ['address', 'contact_info']) do
                  {
                    'address' => {
                      '@type' => 'PostalAddress',
                      'streetAddress' => @content.address.street_address,
                      'postalCode' => @content.address.postal_code,
                      'addressLocality' => @content.address.address_locality,
                      'addressCountry' => @content.country_code.first.classification_aliases.first.name,
                      'name' => @content.contact_info.name,
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
                        '@type' => 'Action',
                        'name' => @content.potential_action.first.name,
                        'url' => @content.potential_action.first.url
                      }
                    ]
                  }
                end

                expected_opening_hours_specification_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'v4_opening_hours_specification_result')
                assert_attributes(json_validate, required_attributes, ['opening_hours_specification']) do
                  {
                    'openingHoursSpecification' => expected_opening_hours_specification_hash
                  }
                end

                assert_attributes(json_validate, required_attributes, ['text', 'price_range', 'author', 'price', 'directions', 'parking', 'hours_available', 'feratel_content_score']) do
                  {
                    'additionalProperty' => [
                      {
                        '@type' => 'PropertyValue',
                        'identifier' => 'text',
                        'name' => 'Beschreibung',
                        'value' => @content.text
                      },
                      {
                        '@type' => 'PropertyValue',
                        'identifier' => 'priceRange',
                        'name' => 'Preis-Info',
                        'value' => @content.price_range
                      },
                      {
                        '@type' => 'PropertyValue',
                        'identifier' => 'author',
                        'name' => 'Autor',
                        'value' => @content.author
                      },
                      {
                        '@type' => 'PropertyValue',
                        'identifier' => 'price',
                        'name' => 'Preis',
                        'value' => @content.price
                      },
                      {
                        '@type' => 'PropertyValue',
                        'identifier' => 'directions',
                        'name' => 'Anfahrtsbeschreibung',
                        'value' => @content.directions
                      },
                      {
                        '@type' => 'PropertyValue',
                        'identifier' => 'parking',
                        'name' => 'Parkmöglichkeit',
                        'value' => @content.parking
                      },
                      {
                        '@type' => 'PropertyValue',
                        'identifier' => 'hoursAvailable',
                        'name' => 'Service-Zeiten',
                        'value' => @content.hours_available
                      },
                      {
                        '@type' => 'PropertyValue',
                        'identifier' => 'feratelContentScore',
                        'name' => 'ContentScore',
                        'value' => @content.feratel_content_score
                      }
                    ]
                  }
                end

                assert_attributes(json_validate, required_attributes, ['location', 'latitude', 'longitude', 'elevation']) do
                  {
                    'geo' => {
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