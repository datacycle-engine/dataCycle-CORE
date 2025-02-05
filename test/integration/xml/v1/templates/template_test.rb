# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Xml
    module V1
      class TemplateTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers

        setup do
          @routes = Engine.routes
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'TestArtikel' })
          @content.set_data_hash(data_hash: { 'text' => 'Hello World!' }, partial_update: true, prevent_history: true)
          @content.save!
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'change type of data for xml' do
          new_type = 'hugo'
          @content.schema['xml'] = { 'type' => new_type }
          @content.thing_template.define_singleton_method(:readonly?) { false }
          @content.thing_template.update_column(:schema, @content.schema)

          get xml_v1_thing_path(id: @content)
          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)

          data_hash = xml_data.dig('RDF', 'thing')
          assert_equal(new_type, data_hash['type'])
        end

        test 'xml parameter name renames property when redered' do
          @content.schema['properties']['text']['xml'] = { 'name' => 'alternative' }
          @content.thing_template.define_singleton_method(:readonly?) { false }
          @content.thing_template.update_column(:schema, @content.schema)

          get xml_v1_thing_path(id: @content)
          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)

          data_hash = xml_data.dig('RDF', 'thing')
          assert_equal(@content.text, data_hash['alternative'])
        end

        test 'xml parameter name renames property when redered and camelize output name' do
          @content.schema['properties']['text']['xml'] = { 'name' => 'new_name' }
          @content.thing_template.define_singleton_method(:readonly?) { false }
          @content.thing_template.update_column(:schema, @content.schema)

          get xml_v1_thing_path(id: @content)
          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)

          data_hash = xml_data.dig('RDF', 'thing')
          assert_equal(@content.text, data_hash['newName'])
        end

        test 'xml property can be disabled' do
          @content.schema['properties']['text']['xml'] = { 'disabled' => true }
          @content.thing_template.define_singleton_method(:readonly?) { false }
          @content.thing_template.update_column(:schema, @content.schema)

          get xml_v1_thing_path(id: @content)
          assert_response(:success)
          assert_equal('application/xml; charset=utf-8', response.content_type)
          xml_data = Hash.from_xml(Nokogiri::XML(response.body).to_xml)

          data_hash = xml_data.dig('RDF', 'thing')
          assert(@content.text.present?)
          assert_nil(data_hash['text'])
        end
      end
    end
  end
end
