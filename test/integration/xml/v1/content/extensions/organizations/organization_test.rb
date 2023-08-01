# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      module Content
        module Extensions
          module Organizations
            class Organization < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('organization')
                sign_in(User.find_by(email: 'tester@datacycle.at'))
                @content.description = 'Random Description'
                @content.save
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'xml of stored content exists and is correct' do
                get xml_v1_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')

                # validate header
                assert_equal('https://schema.org/', xml_data.dig('context'))
                assert_equal('Organization', xml_data.dig('type'))
                assert_equal('Organization', xml_data.dig('contentType'))
                assert_equal(root_url[0...-1] + xml_v1_thing_path(id: @content), xml_data.dig('id'))
                assert_equal(@content.id, xml_data.dig('identifier'))
                assert_equal(root_url[0...-1] + thing_path(@content), xml_data.dig('url'))
                assert_equal('de', xml_data.dig('inLanguage'))

                # content data
                assert_equal(@content.name, xml_data.dig('name'))
                assert_equal(@content.description, xml_data.dig('description'))

                postal_address = @content.address.to_h.transform_keys { |key| key.camelize(:lower) }
                contact_info = @content.contact_info.to_h.transform_keys { |key| key.camelize(:lower) }
                address = { 'type' => 'PostalAddress' }.merge(postal_address)
                assert_equal(address, xml_data.dig('address'))
                assert_equal(contact_info, xml_data.dig('contactInfo'))
                assert_equal(@content.country_code.first.name, xml_data.dig('countryCode', 'classification', 'name'))

                assert_equal(@content.image.first.id, xml_data.dig('image', 'thing', 'identifier'))
              end

              test 'stored item can be found via different endpoints' do
                get(xml_v1_things_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Organization' }
                assert_equal(@content.id, xml_data.dig('identifier'))

                get(xml_v1_contents_search_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Organization' }
                assert_equal(@content.id, xml_data.dig('identifier'))

                get(xml_v1_organizations_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Organization' }
                assert_equal(@content.id, xml_data.dig('identifier'))
              end
            end
          end
        end
      end
    end
  end
end
