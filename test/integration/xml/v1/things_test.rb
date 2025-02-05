# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      class ThingTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          DataCycleCore::Thing.delete_all
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
        end

        setup do
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'xml of stored article exists' do
          get xml_v1_thing_path(id: @content)

          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)
          assert_equal('TestArtikel', xml_data.dig('RDF', 'thing', 'name'))
        end

        test 'stored article can be found and is correct' do
          get xml_v1_things_path

          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)

          assert(xml_data.dig('RDF', 'thing').present?)
          data_hash = [xml_data.dig('RDF', 'thing')].flatten.detect { |item| item['contentType'] == 'Artikel' }

          assert_equal('https://schema.org/', data_hash['context'])
          assert_equal('CreativeWork', data_hash['type'])
          assert_equal('Artikel', data_hash['contentType'])
          assert(data_hash['id'].present?)
          assert_equal(@content.id, data_hash['identifier'])
          assert(data_hash['url'].present?)
          assert_equal('de', data_hash['inLanguage'])
          assert_equal('TestArtikel', data_hash['name'])
        end

        test 'stored article can be found in different ways' do
          get(xml_v1_contents_search_path)
          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data_search = Hash.from_xml(Nokogiri::XML(response.body).to_xml)

          get(xml_v1_things_path)
          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data_things = Hash.from_xml(Nokogiri::XML(response.body).to_xml)

          assert_equal(xml_data_search, xml_data_things)

          get(xml_v1_contents_search_path(type: 'creative_works'))
          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data_search = Hash.from_xml(Nokogiri::XML(response.body).to_xml)

          get(xml_v1_creative_works_path)
          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data_creative_works = Hash.from_xml(Nokogiri::XML(response.body).to_xml)

          assert_equal(xml_data_search, xml_data_creative_works)
        end
      end
    end
  end
end
