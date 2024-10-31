# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Content
        module Extensions
          module Persons
            class PersonDataTest < DataCycleCore::V4::Base
              include DataCycleCore::ApiHelper

              before(:all) do
                @content = DataCycleCore::V4::DummyDataHelper.create_data('person')
                @content.reload
              end

              test 'api_v4_thing_path validate full person with default params' do
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
                assert_attributes(json_validate, required_attributes, ['description', 'job_title', 'given_name', 'family_name', 'honorific_prefix', 'honorific_suffix', 'dc:slug']) do
                  {
                    'description' => @content.description,
                    'jobTitle' => @content.job_title,
                    'givenName' => @content.given_name,
                    'familyName' => @content.family_name,
                    'honorificPrefix' => @content.honorific_prefix,
                    'honorificSuffix' => @content.honorific_suffix,
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

              # TODO: test will fail, check for correct fallback handling
              # test 'api_v4_thing_path validate full person with language en for not translated' do
              #   assert_full_thing_datahash(@content)
              #   params = {
              #     id: @content.id,
              #     language: 'en'
              #   }
              #   post api_v4_thing_path(params)
              #   json_data = JSON.parse response.body
              #   json_validate = json_data.dup.dig('@graph').first
              #   assert_context(json_data.dig('@context'), 'de')
              #
              #   # test full event data
              #   required_attributes = required_multilingual_validation_attributes(@content)
              #
              #   # test minimal
              #   assert_attributes(json_validate, required_attributes, ['id', 'name']) do
              #     {
              #       '@id' => @content.id,
              #       '@type' => 'Person'
              #     }
              #   end
              #
              #   # validate language
              #   assert_attributes(json_validate, required_attributes, []) do
              #     {
              #       'dc:multilingual' => true,
              #       'dc:translation' => [
              #         'de'
              #       ]
              #     }
              #   end
              #
              #   # plain attributes without transformation
              #   assert_attributes(json_validate, required_attributes, ['description', 'job_title', 'given_name', 'family_name', 'honorific_prefix', 'honorific_suffix']) do
              #     {
              #       'givenName' => @content.given_name,
              #       'familyName' => @content.family_name
              #     }
              #   end
              #
              #   # disabled attributes
              #   assert_attributes(json_validate, required_attributes, ['validity_period']) do
              #     {}
              #   end
              #
              # # cc_rel
              # assert_attributes(json_validate, required_attributes, ['url', 'license', 'use_guidelines', 'attribution_url', 'attribution_name', 'license_classification']) do
              #   # license is overwritten by license_classification
              #   {
              #     'cc:license' => @content.license_classification.first.classification_aliases.first.uri,
              #     'cc:useGuidelines' => @content.use_guidelines,
              #     'url' => @content.attribution_url,
              #     'copyrightNotice' => @content.copyright_notice_computed
              #   }
              # end
              #
              #   # address
              #   # must fail !!!!
              #   assert_attributes(json_validate, required_attributes, ['address', 'contact_info']) do
              #     {
              #       'address' => {
              #         '@type' => 'PostalAddress',
              #         'streetAddress' => @content.address.street_address,
              #         'postalCode' => @content.address.postal_code,
              #         'addressLocality' => @content.address.address_locality,
              #         'addressCountry' => @content.country_code.first.classification_aliases.first.name,
              #         'name' => @content.contact_info.contact_name,
              #         'telephone' => @content.contact_info.telephone,
              #         'faxNumber' => @content.contact_info.fax_number,
              #         'email' => @content.contact_info.email,
              #         'url' => @content.contact_info.url
              #       }
              #     }
              #   end
              #
              #   # linked default: images, member
              #   assert_attributes(json_validate, required_attributes, ['image', 'member_of']) do
              #     {
              #       'memberOf' => [
              #         @content.member_of.first.to_api_default_values
              #       ],
              #       'image' => [
              #         @content.image.first.to_api_default_values
              #       ]
              #     }
              #   end
              #
              #   assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))
              #
              #   assert_equal([], required_attributes)
              #   assert_equal({}, json_validate)
              # end

              test 'api_v4_thing_path validate full person with default params in language en' do
                data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person_en')
                @content.reload
                I18n.with_locale(:en) { @content.set_data_hash(data_hash: @content.get_data_hash.except(*@content.computed_property_names).merge(data_hash_en)) }

                assert_translated_datahash(data_hash_en, @content)
                assert_translated_thing(@content, 'en')
                assert_full_thing_datahash(@content)

                params = {
                  id: @content.id,
                  language: 'en'
                }
                post api_v4_thing_path(params)
                json_data = response.parsed_body
                json_validate = json_data.dup['@graph'].first

                assert_context(json_data['@context'], 'en')

                # test full event data
                required_attributes = required_validation_attributes(@content)
                # test minimal
                I18n.with_locale(:en) do
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
                        'de',
                        'en'
                      ]
                    }
                  end

                  # plain attributes without transformation
                  assert_attributes(json_validate, required_attributes, ['description', 'job_title', 'given_name', 'family_name', 'honorific_prefix', 'honorific_suffix', 'dc:slug']) do
                    {
                      'description' => @content.description,
                      'jobTitle' => @content.job_title,
                      'givenName' => @content.given_name,
                      'familyName' => @content.family_name,
                      'honorificPrefix' => @content.honorific_prefix,
                      'honorificSuffix' => @content.honorific_suffix,
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
                        'addressCountry' => @content.country_code.first.classification_aliases.first.internal_name,
                        'name' => @content.contact_info.contact_name,
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
                end
                assert_equal([], required_attributes)
                assert_equal({}, json_validate)
              end

              test 'api_v4_thing_path validate full person with default params in language en and de' do
                data_hash_en = DataCycleCore::TestPreparations.load_dummy_data_hash('persons', 'v4_person_en')
                I18n.with_locale(:en) { @content.set_data_hash(data_hash: @content.get_data_hash.except(*@content.computed_property_names).merge(data_hash_en)) }
                @content.reload

                assert_translated_datahash(data_hash_en, @content)
                assert_translated_thing(@content, :en)
                assert_full_thing_datahash(@content)

                params = {
                  id: @content.id,
                  language: 'en,de'
                }
                post api_v4_thing_path(params)
                json_data = response.parsed_body
                json_validate = json_data.dup['@graph'].first

                assert_context(json_data['@context'], params[:language])

                # test full event data
                required_attributes = required_validation_attributes(@content)
                # test minimal
                assert_attributes(json_validate, required_attributes, ['id', 'given_name', 'family_name']) do
                  {
                    '@id' => @content.id,
                    '@type' => @content.api_type,
                    'givenName' => @content.given_name,
                    'familyName' => @content.family_name
                  }
                end

                # validate language
                assert_attributes(json_validate, required_attributes, []) do
                  {
                    'dc:multilingual' => true,
                    'dc:translation' => [
                      'de',
                      'en'
                    ]
                  }
                end

                # plain attributes without transformation
                assert_translated_attributes(json_validate, required_attributes, ['name', 'description', 'job_title', 'honorific_prefix', 'honorific_suffix', 'use_guidelines', 'dc:slug']) do
                  {
                    'name' => translated_value(@content, 'name', ['de', 'en']),
                    'description' => translated_value(@content, 'description', ['de', 'en']),
                    'jobTitle' => translated_value(@content, 'job_title', ['de', 'en']),
                    'honorificPrefix' => translated_value(@content, 'honorific_prefix', ['de', 'en']),
                    'honorificSuffix' => translated_value(@content, 'honorific_suffix', ['de', 'en']),
                    'cc:useGuidelines' => translated_value(@content, 'use_guidelines', ['de', 'en']),
                    'dc:slug' => translated_value(@content, 'slug', ['de', 'en'])
                  }
                end

                # disabled attributes
                assert_attributes(json_validate, required_attributes, ['validity_period']) do
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

                # address
                assert_translated_attributes(json_validate, required_attributes, ['address', 'contact_info']) do
                  {
                    'address' => {
                      '@id' => generate_uuid(@content.id, 'address'),
                      '@type' => 'PostalAddress',
                      'streetAddress' => @content.address.street_address,
                      'postalCode' => @content.address.postal_code,
                      'addressLocality' => @content.address.address_locality,
                      'addressCountry' => @content.country_code.first.classification_aliases.first.internal_name,
                      'name' => translated_value(@content, 'contact_info.contact_name', ['de', 'en']),
                      'telephone' => translated_value(@content, 'contact_info.telephone', ['de', 'en']),
                      'faxNumber' => translated_value(@content, 'contact_info.fax_number', ['de', 'en']),
                      'email' => translated_value(@content, 'contact_info.email', ['de', 'en']),
                      'url' => translated_value(@content, 'contact_info.url', ['de', 'en'])
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

              test 'api_v4_thing_path validate full person and person_overlay with default params' do
                assert_full_thing_datahash(@content)
                content_overlay = DataCycleCore::V4::DummyDataHelper.create_data('person_overlay')
                assert_full_thing_datahash(content_overlay)
                @content.set_data_hash(partial_update: true, prevent_history: true, data_hash: { 'overlay' => [content_overlay.get_data_hash] })
                @content.reload

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
                assert_attributes(json_validate, required_attributes, ['id']) do
                  {
                    '@id' => @content.id,
                    '@type' => @content.api_type
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
                assert_attributes(json_validate, required_attributes, ['description', 'job_title', 'honorific_prefix', 'honorific_suffix', 'dc:slug']) do
                  {
                    'description' => @content.description,
                    'jobTitle' => @content.job_title,
                    'honorificPrefix' => @content.honorific_prefix,
                    'honorificSuffix' => @content.honorific_suffix,
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

                # linked default: images, member
                assert_attributes(json_validate, required_attributes, ['member_of']) do
                  {
                    'memberOf' => [
                      @content.member_of.first.to_api_default_values
                    ]
                  }
                end

                # overlay properties
                assert_attributes(json_validate, required_attributes, ['given_name', 'family_name', 'name']) do
                  {
                    'givenName' => content_overlay.given_name,
                    'familyName' => content_overlay.family_name,
                    'name' => content_overlay.name
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
                      '@id' => generate_uuid(@content.id, 'address'),
                      '@type' => 'PostalAddress',
                      'streetAddress' => content_overlay.address.street_address,
                      'postalCode' => content_overlay.address.postal_code,
                      'addressLocality' => content_overlay.address.address_locality,
                      'addressCountry' => content_overlay.country_code.first.classification_aliases.first.name,
                      'name' => content_overlay.contact_info.contact_name,
                      'telephone' => content_overlay.contact_info.telephone,
                      'faxNumber' => content_overlay.contact_info.fax_number,
                      'email' => content_overlay.contact_info.email,
                      'url' => content_overlay.contact_info.url
                    }
                  }
                end

                assert_classifications(json_validate, @content.classification_aliases.to_a.select { |c| c.visible?('api') }.map(&:to_api_default_values))

                assert_equal([], required_attributes)
                assert_equal({}, json_validate)
              end

              test 'api_v4_thing_path validate full person and person_overlay_minimal with default params' do
                assert_full_thing_datahash(@content)
                content_overlay = DataCycleCore::V4::DummyDataHelper.create_data('person_overlay_minimal')
                assert_full_thing_datahash(content_overlay)
                @content.set_data_hash(partial_update: true, prevent_history: true, data_hash: { 'overlay' => [content_overlay.get_data_hash] })
                @content.reload

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
                assert_attributes(json_validate, required_attributes, ['id']) do
                  {
                    '@id' => @content.id,
                    '@type' => @content.api_type
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
                assert_attributes(json_validate, required_attributes, ['description', 'job_title', 'honorific_prefix', 'honorific_suffix', 'dc:slug']) do
                  {
                    'description' => @content.description,
                    'jobTitle' => @content.job_title,
                    'honorificPrefix' => @content.honorific_prefix,
                    'honorificSuffix' => @content.honorific_suffix,
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

                # linked default: images, member
                assert_attributes(json_validate, required_attributes, ['member_of']) do
                  {
                    'memberOf' => [
                      @content.member_of.first.to_api_default_values
                    ]
                  }
                end

                # overlay properties
                assert_attributes(json_validate, required_attributes, ['given_name', 'family_name', 'name']) do
                  {
                    'givenName' => content_overlay.given_name,
                    'familyName' => content_overlay.family_name,
                    'name' => content_overlay.name
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
                      '@id' => generate_uuid(@content.id, 'address'),
                      '@type' => 'PostalAddress',
                      'streetAddress' => content_overlay.address.street_address,
                      'postalCode' => @content.address.postal_code,
                      'addressLocality' => @content.address.address_locality,
                      'addressCountry' => @content.country_code.first.classification_aliases.first.name,
                      'name' => @content.contact_info.contact_name,
                      'telephone' => content_overlay.contact_info.telephone,
                      'faxNumber' => @content.contact_info.fax_number,
                      'email' => @content.contact_info.email,
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
