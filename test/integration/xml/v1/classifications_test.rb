# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      class ClassificationTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
        before(:all) do
          DataCycleCore::Thing.delete_all
        end

        setup do
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'xml for classification_trees is reachable' do
          get xml_v1_classification_trees_path

          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)
          assert(xml_data.dig('RDF', 'classificationTree').size.positive?)
        end

        test 'xml for specific classificaiton_trees' do
          classification_tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Inhaltstypen')
          get xml_v1_classification_tree_path(id: classification_tree)

          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)
          assert_equal(classification_tree.id, xml_data.dig('RDF', 'classificationTree', 'id'))
          assert_equal(classification_tree.name, xml_data.dig('RDF', 'classificationTree', 'name'))
        end

        test 'xml of classifications within a classification_tree' do
          classification_tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Inhaltstypen')
          get classifications_xml_v1_classification_tree_path(id: classification_tree)

          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)

          total = classification_tree.classification_trees.count
          assert_equal(total, xml_data['RDF']['classifications']['classification'].count)
        end
      end
    end
  end
end
