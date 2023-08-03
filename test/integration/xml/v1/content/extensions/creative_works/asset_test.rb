# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      module Content
        module Extensions
          module CreativeWorks
            class Asset < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('asset')
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'xml of stored image exists and is correct' do
                get xml_v1_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')

                # validate header
                assert_equal('https://schema.org/', xml_data.dig('context'))
                assert_equal('CreativeWork', xml_data.dig('type'))
                assert_equal('Datei', xml_data.dig('contentType'))
                assert_equal(root_url[0...-1] + xml_v1_thing_path(id: @content), xml_data.dig('id'))
                assert_equal(@content.id, xml_data.dig('identifier'))
                assert_equal(root_url[0...-1] + thing_path(@content), xml_data.dig('url'))
                assert_equal('de', xml_data.dig('inLanguage'))

                # content data
                assert_equal(@content.name, xml_data.dig('name'))
                assert_equal(@content.description, xml_data.dig('description'))
                assert_equal(@content.content_url, xml_data.dig('contentUrl'))
                assert_equal(@content.content_size, xml_data.dig('contentSize').to_f)
                assert_equal(@content.file_format, xml_data.dig('fileFormat'))
              end

              test 'stored item can be found via different endpoints' do
                get(xml_v1_things_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item.dig('contentType') == 'Datei' }
                assert_equal(@content.id, xml_data.dig('identifier'))

                get(xml_v1_contents_search_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item.dig('contentType') == 'Datei' }
                assert_equal(@content.id, xml_data.dig('identifier'))

                get(xml_v1_creative_works_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = [Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')].flatten.detect { |item| item.dig('contentType') == 'Datei' }
                assert_equal(@content.id, xml_data.dig('identifier'))
              end
            end
          end
        end
      end
    end
  end
end
