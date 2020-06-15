# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        module Extensions
          module Organizations
            class OrganizationDataTest < DataCycleCore::V4::Base
              setup do
                # create a person to make sure person and organization are connected
                @person = DataCycleCore::V4::DummyDataHelper.create_data('person')
                @content = @person.member_of.first
              end

              test 'api_v4_thing_path validate full organization with default params' do
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
                    '@type' => 'Organization',
                    'name' => @content.name,
                    'legalName' => @content.name
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
                  # license is overwritten by license_classification
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
                assert_attributes(json_validate, required_attributes, ['image', 'member']) do
                  {
                    'member' => [
                      @content.member.first.to_api_default_values
                    ],
                    'image' => [
                      @content.image.first.to_api_default_values
                    ]
                  }
                end

                # locations content_location, virtual_location
                assert_attributes(json_validate, required_attributes, ['content_location']) do
                  {
                    'location' => [
                      @content.content_location.first.to_api_default_values
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
