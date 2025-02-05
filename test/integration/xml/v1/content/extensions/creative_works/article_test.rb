# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      module Content
        module Extensions
          module CreativeWorks
            class Article < DataCycleCore::TestCases::ActionDispatchIntegrationTest
              before(:all) do
                DataCycleCore::Thing.delete_all
                @content = DataCycleCore::DummyDataHelper.create_data('article')
              end

              setup do
                sign_in(User.find_by(email: 'tester@datacycle.at'))
              end

              test 'xml of stored article exists' do
                get xml_v1_thing_path(id: @content)

                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing')

                # validate header
                assert_equal('https://schema.org/', xml_data['context'])
                assert_equal('CreativeWork', xml_data['type'])
                assert_equal('Artikel', xml_data['contentType'])
                assert_equal(root_url[0...-1] + xml_v1_thing_path(id: @content), xml_data['id'])
                assert_equal(@content.id, xml_data['identifier'])
                assert_equal(root_url[0...-1] + thing_path(@content), xml_data['url'])
                assert_equal('de', xml_data['inLanguage'])

                # validity period
                # TODO: (move to generic tests)
                assert_equal(@content.validity_period.valid_from, xml_data.dig('validityPeriod', 'validFrom').to_date)
                assert_equal(@content.validity_period.valid_until, xml_data.dig('validityPeriod', 'validUntil').to_date)

                # content data
                assert_equal(@content.name, xml_data['name'])
                assert_equal(@content.description, xml_data['description'])
                assert_equal(@content.text, xml_data['text'])
                assert_equal(@content.alternative_headline, xml_data['alternativeHeadline'])
                assert_equal(@content.link_name, xml_data['linkName'])
                assert_equal(@content.url, xml_data['sameAs'])

                assert_equal(@content.image.first.id, xml_data.dig('image', 'thing', 'identifier'))
                assert_equal(@content.author.first.id, xml_data.dig('author', 'thing', 'identifier'))
                assert_equal(@content.about.first.id, xml_data.dig('about', 'thing', 'identifier'))
                assert_equal(@content.content_location.first.id, xml_data.dig('contentLocation', 'thing', 'identifier'))

                # check for tag classification and keyword transformation
                assert_equal(@content.tags.first.name, xml_data.dig('tags', 'classification', 'name'))
                assert_equal(@content.tags.first.name, xml_data['keywords'])
                assert_equal(@content.keywords, xml_data['keywords'])
              end

              test 'stored item can be found via different endpoints' do
                get(xml_v1_things_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing').detect { |item| item['contentType'] == 'Artikel' }
                assert_equal(@content.id, xml_data['identifier'])

                get(xml_v1_contents_search_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing').detect { |item| item['contentType'] == 'Artikel' }
                assert_equal(@content.id, xml_data['identifier'])

                get(xml_v1_creative_works_path)
                assert_response(:success)
                assert_equal('application/xml; charset=utf-8', response.content_type)
                xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml).dig('RDF', 'thing').detect { |item| item['contentType'] == 'Artikel' }
                assert_equal(@content.id, xml_data['identifier'])
              end
            end
          end
        end
      end
    end
  end
end
