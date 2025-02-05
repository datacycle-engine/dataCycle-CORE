# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      class RoutingTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          DataCycleCore::Thing.delete_all
          @test_content = DataCycleCore::DummyDataHelper.create_data('tour')
        end

        setup do
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test '/xml/v1/contents/search default results' do
          get(xml_v1_contents_search_path)
          count = DataCycleCore::Filter::Search.new.count

          assert_response(:success)
          assert_equal(response.content_type, 'application/xml; charset=utf-8')
          xml_data = Nokogiri::XML(response.body)
          assert_equal(count, xml_data.children.first.children.map(&:name).count { |item| item == 'thing' })
        end

        test '/xml/v1/contents/search with available API params' do
          get(xml_v1_contents_search_path)
          count = DataCycleCore::Filter::Search.new.count

          included_params = DataCycleCore::Xml::V1::ContentsController::ALLOWED_INCLUDE_PARAMETERS
          included_params.each do |param|
            get(xml_v1_contents_search_path(include: param))
            assert_response(:success)
            assert_equal(response.content_type, 'application/xml; charset=utf-8')
            xml_data = Nokogiri::XML(response.body)
            assert_equal(count, xml_data.children.first.children.map(&:name).count { |item| item == 'thing' })
          end

          mode_params = DataCycleCore::Xml::V1::ContentsController::ALLOWED_MODE_PARAMETERS
          mode_params.each do |param|
            get(xml_v1_contents_search_path(mode: param))
            assert_response(:success)
            assert_equal(response.content_type, 'application/xml; charset=utf-8')
            xml_data = Nokogiri::XML(response.body)
            assert_equal(count, xml_data.children.first.children.map(&:name).count { |item| item == 'thing' })
          end
        end

        test '/xml/v1/creative_works' do
          get xml_v1_creative_works_path
          count = DataCycleCore::Filter::Search.new.schema_type('CreativeWork').count

          assert_response :success
          assert_equal response.content_type, 'application/xml; charset=utf-8'
          xml_data = Nokogiri::XML(response.body)
          assert_equal(count, xml_data.children.first.children.map(&:name).count { |item| item == 'thing' })
        end

        test '/xml/v1/places' do
          get xml_v1_places_path
          count = DataCycleCore::Filter::Search.new.schema_type('Place').count

          assert_response :success
          assert_equal response.content_type, 'application/xml; charset=utf-8'
          xml_data = Nokogiri::XML(response.body)
          assert_equal(count, xml_data.children.first.children.map(&:name).count { |item| item == 'thing' })
        end

        test '/xml/v1/events' do
          get xml_v1_events_path
          count = DataCycleCore::Filter::Search.new.schema_type('Event').count

          assert_response :success
          assert_equal response.content_type, 'application/xml; charset=utf-8'
          xml_data = Nokogiri::XML(response.body)
          assert_equal(count, xml_data.children.first.children.map(&:name).count { |item| item == 'thing' })
        end

        test '/xml/v1/persons' do
          get xml_v1_persons_path
          count = DataCycleCore::Filter::Search.new.schema_type('Person').count

          assert_response :success
          assert_equal response.content_type, 'application/xml; charset=utf-8'
          xml_data = Nokogiri::XML(response.body)
          assert_equal(count, xml_data.children.first.children.map(&:name).count { |item| item == 'thing' })
        end

        test '/xml/v1/organizations' do
          get xml_v1_organizations_path
          count = DataCycleCore::Filter::Search.new.schema_type('Organization').count

          assert_response :success
          assert_equal response.content_type, 'application/xml; charset=utf-8'
          xml_data = Nokogiri::XML(response.body)
          assert_equal(count, xml_data.children.first.children.map(&:name).count { |item| item == 'thing' })
        end

        test '/xml/v1/thing Xml for article' do
          name = "test_artikel_#{Time.now.getutc.to_i}"
          post things_path, params: {
            thing: {
              datahash: {
                name:
              }
            },
            table: 'things',
            template: 'Artikel',
            locale: 'de'
          }
          assert_equal('Artikel wurde erfolgreich erstellt.', flash[:success])

          content = DataCycleCore::Thing.where_translated_value(name:).first

          get xml_v1_thing_path(id: content)

          assert_response :success
          assert_equal response.content_type, 'application/xml; charset=utf-8'
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)
          assert_equal(name, xml_data.dig('RDF', 'thing', 'name'))
        end

        test '/xml/v1/classification_trees' do
          params = {
            page: {
              size: 100
            }
          }
          get xml_v1_classification_trees_path(params)

          count = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('xml').count

          assert_response :success
          assert_equal response.content_type, 'application/xml; charset=utf-8'
          xml_data = Nokogiri::XML(response.body)
          assert_equal(count, xml_data.children.first.children.map(&:name).count { |item| item == 'classificationTree' })

          hash = Hash.from_xml(xml_data.to_xml)
          test_classification = hash.dig('RDF', 'classificationTree').detect { |item| item['name'] == 'Tags' }['id']

          get xml_v1_classification_tree_path(id: test_classification)
          assert_response :success
          assert_equal response.content_type, 'application/xml; charset=utf-8'
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)
          assert_equal(test_classification, xml_data.dig('RDF', 'classificationTree', 'id'))

          get classifications_xml_v1_classification_tree_path(id: test_classification)
          assert_response :success
          assert_equal response.content_type, 'application/xml; charset=utf-8'
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)
          assert_equal(true, xml_data.dig('RDF', 'classifications', 'classification').count.positive?)
        end
      end
    end
  end
end
