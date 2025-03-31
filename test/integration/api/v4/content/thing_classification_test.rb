# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module Content
        class ThingClassificationTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          include DataCycleCore::ApiV4Helper

          def embedded_concept_attributes
            ['skos:inScheme', 'skos:topConceptOf', 'skos:broader', 'skos:ancestors']
          end

          before(:all) do
            DataCycleCore::Thing.delete_all
            @routes = Engine.routes
            @content = DataCycleCore::DummyDataHelper.create_data('poi')
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          def add_content_header_fields(array)
            expanded_fields = array.dup
            expanded_fields += ['dct:modified', 'dct:created', 'dc:touched', 'dc:entityUrl']

            array.each do |field|
              expanded_fields += ["#{field}.dct:modified"]
              expanded_fields += ["#{field}.dct:created"]
              expanded_fields += ["#{field}.dc:touched"]
              expanded_fields += ["#{field}.dc:entityUrl"]
            end

            expanded_fields
          end

          test 'concepts at /api/v4/things/:id serializes with only minimal header' do
            get api_v4_thing_path(id: @content.id)
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            header = json_data.slice(*full_header_attributes)
            data = full_header_data(@content)
            assert_equal(header, data)

            assert_compact_classification_header(json_data['dc:classification'])
          end

          test 'concepts at /api/v4/things/:id with include concepts --> full data' do
            get api_v4_thing_path(id: @content.id, include: 'dc:classification')
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            header = json_data.slice(*full_header_attributes)
            data = full_header_data(@content)
            assert_equal(header, data)

            assert_concept_attributes(json_data.dig('dc:classification', 0))
            json_data.dig('dc:classification', 0).slice(*embedded_concept_attributes).each do |embedded_attribute|
              assert_compact_header(Array(json_data.dig('dc:classification', 0, embedded_attribute)))
            end
          end

          test 'concepts at /api/v4/things/:id with include dc:classification,dc:classification.skos:inScheme' do
            get api_v4_thing_path(id: @content.id, include: 'dc:classification,dc:classification.skos:inScheme')
            assert_response :success

            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            header = json_data.slice(*full_header_attributes)
            data = full_header_data(@content)
            assert_equal(header, data)

            assert_concept_attributes(json_data.dig('dc:classification', 0))
            json_data.dig('dc:classification', 0).slice(*embedded_concept_attributes).each do |embedded_attribute|
              assert_compact_header(Array(json_data.dig('dc:classification', 0, embedded_attribute)))
            end

            assert_concept_attributes(json_data.dig('dc:classification', 0, 'skos:inScheme'))
          end

          test 'include dc:classification,dc:classification.skos:inScheme is equal to include dc:classification.skos:inScheme' do
            get api_v4_thing_path(id: @content.id, include: 'dc:classification,dc:classification.skos:inScheme')
            assert_response :success
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            get api_v4_thing_path(id: @content.id, include: 'dc:classification.skos:inScheme')
            assert_response :success
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data2 = response.parsed_body
            json_data2 = json_data2['@graph'].first
            assert_equal(json_data, json_data2)
          end

          test 'concepts at /api/v4/things/:id with fields dc:classification.skos:inScheme.skos:prefLabel' do
            get api_v4_thing_path(id: @content.id, fields: 'dc:classification.skos:inScheme.skos:prefLabel')
            assert_response :success
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            assert_equal(1, json_data['dc:classification'].size)
            assert_equal(['@id', '@type', 'skos:inScheme'], json_data.dig('dc:classification', 0).keys)
            assert_equal(['@id', '@type', 'skos:prefLabel'], json_data.dig('dc:classification', 0, 'skos:inScheme').keys)
          end

          test 'combo of fields, include' do
            get api_v4_thing_path(id: @content.id, fields: 'dc:classification.skos:inScheme.skos:prefLabel', include: 'dc:classification')
            assert_response :success
            assert_equal(response.content_type, 'application/json; charset=utf-8')
            json_data = response.parsed_body
            json_data = json_data['@graph'].first

            assert_equal(1, json_data['dc:classification'].size)
            assert_concept_attributes(json_data.dig('dc:classification', 0))
            json_data.dig('dc:classification', 0).slice(*embedded_concept_attributes).each do |embedded_attribute|
              assert_compact_header(Array(json_data.dig('dc:classification', 0, embedded_attribute)))
            end
            assert_equal(['@id', '@type', 'skos:prefLabel'], json_data.dig('dc:classification', 0, 'skos:inScheme').keys)
          end

          test 'testing fields for wildcard - nested classification fields' do
            fields = ['*', 'dc:classification.*', 'dc:classification.skos:inScheme.*', 'dc:classification.skos:topConceptOf.*']
            includes = ['dc:classification', 'dc:classification.skos:inScheme', 'dc:classification.skos:topConceptOf']

            get api_v4_thing_path(id: @content.id, fields: nil, include: add_content_header_fields(includes)&.join(','))
            assert_response(:success)
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data_includes = response.parsed_body['@graph'].first

            get api_v4_thing_path(id: @content.id, fields: fields&.join(','), include: nil)
            assert_response(:success)
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data_wildcard = response.parsed_body['@graph'].first

            assert_equal(json_data_includes.keys.sort, json_data_wildcard.keys.sort)
            assert_equal(json_data_includes['dc:classification'].first.keys.sort, json_data_wildcard['dc:classification'].first.keys.sort)
            assert_equal(json_data_includes['dc:classification'][0]['skos:inScheme'].keys.sort, json_data_wildcard['dc:classification'][0]['skos:inScheme'].keys.sort)
            assert_equal(json_data_includes['dc:classification'][0]['skos:topConceptOf'].keys.sort, json_data_wildcard['dc:classification'][0]['skos:topConceptOf'].keys.sort)
          end

          test 'testing fields for wildcard - dc:classification' do
            fields = ['dc:classification.*']
            includes = ['dc:classification']

            get api_v4_thing_path(id: @content.id, fields: nil, include: add_content_header_fields(includes)&.join(','))
            assert_response(:success)
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data_includes = response.parsed_body['@graph'].first

            get api_v4_thing_path(id: @content.id, fields: fields&.join(','), include: nil)
            assert_response(:success)
            assert_equal('application/json; charset=utf-8', response.content_type)
            json_data_wildcard = response.parsed_body['@graph'].first

            assert_equal(['@id', '@type', 'dc:classification'], json_data_wildcard.keys.sort)
            assert_equal(json_data_includes['dc:classification'].first.keys.sort, json_data_wildcard['dc:classification'].first.keys.sort)
          end
        end
      end
    end
  end
end
