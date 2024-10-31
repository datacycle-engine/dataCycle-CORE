# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      module Content
        module Extensions
          module Places
            class Poi < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('poi')
                @content.set_data_hash(data_hash: { 'description' => 'some description', 'text' => 'some text' }, partial_update: true, prevent_history: true)
                @content.save
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'xml of stored item exists and is correct' do
                get xml_v1_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')

                # validate header
                assert_equal('https://schema.org/', xml_data['context'])
                assert_equal('Place', xml_data['type'])
                assert_equal('POI', xml_data['contentType'])
                assert_equal(root_url[0...-1] + xml_v1_thing_path(id: @content), xml_data['id'])
                assert_equal(@content.id, xml_data['identifier'])
                assert_equal(root_url[0...-1] + thing_path(@content), xml_data['url'])
                assert_equal('de', xml_data['inLanguage'])

                # content data
                assert_equal(@content.name, xml_data['name'])
                assert_equal(@content.description, xml_data['description'])

                assert_equal(@content.text, xml_data['text'])

                assert_equal(@content.longitude, xml_data['longitude'].to_f)
                assert_equal(@content.latitude, xml_data['latitude'].to_f)
                assert_equal(@content.elevation, xml_data['elevation'].to_f)

                postal_address = @content.address.to_h.transform_keys { |key| key.camelize(:lower) }
                contact_info = @content.contact_info.to_h.transform_keys { |key| key.camelize(:lower) }
                address = { 'type' => 'PostalAddress' }.merge(postal_address)
                assert_equal(address, xml_data['address'])
                assert_equal(contact_info, xml_data['contactInfo'])
                assert_equal(@content.country_code.first.name, xml_data.dig('countryCode', 'classification', 'name'))

                assert_equal(@content.image.first.id, xml_data.dig('image', 'thing', 'identifier'))
                assert_equal(@content.primary_image.first.id, xml_data.dig('primaryImage', 'thing', 'identifier'))
                assert_equal(@content.logo.first.id, xml_data.dig('logo', 'thing', 'identifier'))
              end

              test 'testing PlaceOverlay' do
                image_data_hash = DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'api_image')
                image_data_hash['name'] = 'Another Image'
                overlay_image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: image_data_hash)

                data_hash = {
                  'overlay' => [{
                    'name' => 'overlay_name',
                    'description' => 'overlay_description',
                    'image' => [overlay_image.id]
                  }]
                }
                I18n.with_locale(:de) do
                  @content.set_data_hash(data_hash:, partial_update: true, current_user: User.find_by(email: 'tester@datacycle.at'))
                end
                @content.reload

                get xml_v1_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')

                # content data
                assert_equal(data_hash['overlay'].first['name'], xml_data['name'])
                assert_equal(data_hash['overlay'].first['description'], xml_data['description'])
                assert_equal(overlay_image.id, xml_data.dig('image', 'thing', 'identifier'))
              end

              test 'stored item can be found via different endpoints' do
                get(xml_v1_things_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'POI' }
                assert_equal(@content.id, xml_data['identifier'])

                get(xml_v1_contents_search_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'POI' }
                assert_equal(@content.id, xml_data['identifier'])

                get(xml_v1_places_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'POI' }
                assert_equal(@content.id, xml_data['identifier'])
              end
            end
          end
        end
      end
    end
  end
end
