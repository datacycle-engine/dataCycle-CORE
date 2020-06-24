# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        module Extensions
          module Persons
            class PersonDataTest < DataCycleCore::V4::Base
              setup do
                @content = DataCycleCore::V4::DummyDataHelper.create_data('person')
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
                assert_attributes(json_validate, required_attributes, ['id', 'name']) do
                  {
                    '@id' => @content.id,
                    '@type' => 'Person',
                    'name' => @content.title
                  }
                end

                # plain attributes without transformation
                assert_attributes(json_validate, required_attributes, ['description', 'job_title', 'given_name', 'family_name', 'honorific_prefix', 'honorific_suffix']) do
                  {
                    'description' => @content.description,
                    'jobTitle' => @content.job_title,
                    'givenName' => @content.given_name,
                    'familyName' => @content.family_name,
                    'honorificPrefix' => @content.honorific_prefix,
                    'honorificSuffix' => @content.honorific_suffix
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
                assert_attributes(json_validate, required_attributes, ['image', 'member_of']) do
                  {
                    'memberOf' => [
                      @content.member_of.first.to_api_default_values
                    ],
                    'image' => [
                      @content.image.first.to_api_default_values
                    ]
                  }
                end

                assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

                assert_equal([], required_attributes)
                assert_equal({}, json_validate)
              end

              # TODO: fix classifications for overlay:
              # disable ALL classifications in overlays?
              test 'api_v4_thing_path validate full person and person_overlay with default params' do
                assert_full_thing_datahash(@content)
                content_overlay = DataCycleCore::V4::DummyDataHelper.create_data('person_overlay')
                assert_full_thing_datahash(content_overlay)
                @content.set_data_hash(partial_update: true, prevent_history: true, data_hash: { 'overlay' => [content_overlay.get_data_hash] })

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
                    '@type' => 'Person',
                    'name' => @content.title
                  }
                end

                # plain attributes without transformation
                assert_attributes(json_validate, required_attributes, ['description', 'job_title', 'honorific_prefix', 'honorific_suffix']) do
                  {
                    'description' => @content.description,
                    'jobTitle' => @content.job_title,
                    'honorificPrefix' => @content.honorific_prefix,
                    'honorificSuffix' => @content.honorific_suffix
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

                # linked default: images, member
                assert_attributes(json_validate, required_attributes, ['member_of']) do
                  {
                    'memberOf' => [
                      @content.member_of.first.to_api_default_values
                    ]
                  }
                end

                # overlay properties
                assert_attributes(json_validate, required_attributes, ['given_name', 'family_name']) do
                  {
                    'givenName' => content_overlay.given_name,
                    'familyName' => content_overlay.family_name
                  }
                end

                # linked default: images, member
                assert_attributes(json_validate, required_attributes, ['image']) do
                  {
                    'image' => [
                      content_overlay.image.first.to_api_default_values
                    ]
                  }
                end

                # address
                assert_attributes(json_validate, required_attributes, ['address', 'contact_info']) do
                  {
                    'address' => {
                      '@type' => 'PostalAddress',
                      'streetAddress' => content_overlay.address.street_address,
                      'postalCode' => content_overlay.address.postal_code,
                      'addressLocality' => content_overlay.address.address_locality,
                      'addressCountry' => content_overlay.country_code.first.classification_aliases.first.name,
                      'name' => content_overlay.contact_info.name,
                      'telephone' => content_overlay.contact_info.telephone,
                      'faxNumber' => content_overlay.contact_info.fax_number,
                      'email' => content_overlay.contact_info.email,
                      'url' => content_overlay.contact_info.url
                    }
                  }
                end

                assert_classifications(json_validate, (@content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values) + content_overlay.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values)))

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
