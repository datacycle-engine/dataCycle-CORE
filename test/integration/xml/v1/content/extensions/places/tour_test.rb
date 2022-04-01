# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      module Content
        module Extensions
          module Places
            class Tour < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.where(template: false).delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('tour')
                @content.description = 'some description'
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
                assert_equal('https://schema.org/', xml_data.dig('context'))
                assert_equal('Place', xml_data.dig('type'))
                assert_equal('Tour', xml_data.dig('contentType'))
                assert_equal(root_url[0...-1] + xml_v1_thing_path(id: @content), xml_data.dig('id'))
                assert_equal(@content.id, xml_data.dig('identifier'))
                assert_equal(root_url[0...-1] + thing_path(@content), xml_data.dig('url'))
                assert_equal('de', xml_data.dig('inLanguage'))

                # content
                assert_equal(@content.name, xml_data.dig('name'))
                assert_equal(@content.description, xml_data.dig('description'))

                # TODO: check image rendering via minimal or linked
                assert_equal(@content.image.first.id, xml_data.dig('image', 'thing', 'identifier'))
                assert_equal(@content.primary_image.first.id, xml_data.dig('primaryImage', 'thing', 'identifier'))
                assert_equal(@content.logo.first.id, xml_data.dig('logo', 'thing', 'identifier'))
              end

              test 'stored item can be found via different endpoints' do
                get(xml_v1_things_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Tour' }
                assert_equal(@content.id, xml_data.dig('identifier'))

                get(xml_v1_contents_search_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Tour' }
                assert_equal(@content.id, xml_data.dig('identifier'))

                get(xml_v1_places_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item&.dig('contentType') == 'Tour' }
                assert_equal(@content.id, xml_data.dig('identifier'))
              end
            end
          end
        end
      end
    end
  end
end
