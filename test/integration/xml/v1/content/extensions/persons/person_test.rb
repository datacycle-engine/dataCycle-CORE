# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      module Content
        module Extensions
          module Persons
            class Person < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('person')
                @content.description = 'some description'
                @content.save
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'xml of stored person exists and is correct' do
                get xml_v1_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')

                # validate header
                assert_equal('https://schema.org/', xml_data['context'])
                assert_equal('Person', xml_data['type'])
                assert_equal('Person', xml_data['contentType'])
                assert_equal(root_url[0...-1] + xml_v1_thing_path(id: @content), xml_data['id'])
                assert_equal(@content.id, xml_data['identifier'])
                assert_equal(root_url[0...-1] + thing_path(@content), xml_data['url'])
                assert_equal('de', xml_data['inLanguage'])

                # content data
                assert_equal(@content.given_name, xml_data['givenName'])
                assert_equal(@content.family_name, xml_data['familyName'])
                assert_equal(@content.honorific_prefix, xml_data['honorificPrefix'])
                assert_equal(@content.honorific_suffix, xml_data['honorificSuffix'])
                assert_equal(@content.job_title, xml_data['jobTitle'])
                assert_equal(@content.description, xml_data['description'])

                postal_address = @content.address.to_h.transform_keys { |key| key.camelize(:lower) }
                contact_info = @content.contact_info.to_h.transform_keys { |key| key.camelize(:lower) }
                address = { 'type' => 'PostalAddress' }.merge(postal_address)
                assert_equal(address, xml_data['address'])
                assert_equal(contact_info, xml_data['contactInfo'])
                assert_equal(@content.country_code.first.name, xml_data.dig('countryCode', 'classification', 'name'))

                assert_equal(@content.gender.first.name, xml_data.dig('gender', 'classification', 'name'))

                assert_equal(@content.image.first.id, xml_data.dig('image', 'thing', 'identifier'))
              end

              test 'stored item can be found via different endpoints' do
                get(xml_v1_things_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Person' }
                assert_equal(@content.id, xml_data['identifier'])

                get(xml_v1_contents_search_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Person' }
                assert_equal(@content.id, xml_data['identifier'])

                get(xml_v1_persons_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Person' }
                assert_equal(@content.id, xml_data['identifier'])
              end
            end
          end
        end
      end
    end
  end
end
