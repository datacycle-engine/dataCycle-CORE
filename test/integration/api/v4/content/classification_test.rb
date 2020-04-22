# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'v4/validation/concept'

module DataCycleCore
  module Api
    module V4
      class ClassificationTest < ActionDispatch::IntegrationTest
        include Devise::Test::IntegrationHelpers
        include Engine.routes.url_helpers
        include DataCycleCore::ApiV4Helper

        def embedded_concept_attributes
          ['inScheme', 'topConceptOf', 'broader', 'ancestors']
        end

        setup do
          DataCycleCore::Thing.where(template: false).delete_all
          @routes = Engine.routes
          @trees = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('api').count
          sign_in(User.find_by(email: 'tester@datacycle.at'))
        end

        test 'api/v4/concept_schemes parameter filter[:created_since]' do
          get api_v4_concept_schemes_path(filter: { created_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(@trees, json_data['@graph'].size)
          assert_equal(@trees, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'api/v4/concept_schemes parameter filter[:modified_since]' do
          get api_v4_concept_schemes_path(filter: { modified_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(@trees, json_data['@graph'].size)
          assert_equal(@trees, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'api/v4/concept_schemes parameter filter[:deleted_since]' do
          get api_v4_concept_schemes_path(filter: { deleted_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(0, json_data['@graph'].size)
          assert_equal(0, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          DataCycleCore::MasterData::ImportClassifications.import_all(classification_paths: [Rails.root.join('..', 'dummy_data', 'classifications')])
          DataCycleCore::ClassificationTreeLabel.find_by(name: 'Test').destroy

          get api_v4_concept_schemes_path(filter: { deleted_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(1, json_data['@graph'].size)
          assert_equal(1, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'api/v4/concept_schemes/id/concepts parameter filter[:created_since]' do
          tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
          classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
          get classifications_api_v4_concept_scheme_path(id: tree_id, filter: { created_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(classifications, json_data['@graph'].size)
          assert_equal(classifications, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'api/v4/concept_schemes/id/concepts parameter filter[:modified_since]' do
          tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
          classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
          get classifications_api_v4_concept_scheme_path(id: tree_id, filter: { modified_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(classifications, json_data['@graph'].size)
          assert_equal(classifications, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        test 'api/v4/concept_schemes/id/concepts parameter filter[:deleted_since]' do
          DataCycleCore::MasterData::ImportClassifications.import_all(classification_paths: [Rails.root.join('..', 'dummy_data', 'classifications')])
          tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Test').id
          classifications = DataCycleCore::ClassificationAlias.for_tree('Test').count

          get classifications_api_v4_concept_scheme_path(id: tree_id, filter: { deleted_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(0, json_data['@graph'].size)
          assert_equal(0, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          DataCycleCore::ClassificationAlias.for_tree('Test').destroy_all
          get classifications_api_v4_concept_scheme_path(id: tree_id, filter: { deleted_since: (Time.zone.now - 20.years).to_s(:iso8601) })
          assert_response :success

          assert_equal(response.content_type, 'application/json')
          json_data = JSON.parse(response.body)
          assert_equal(classifications, json_data['@graph'].size)
          assert_equal(classifications, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))
        end

        # Latest version

        test 'api/v4/concept_schemes' do
          post api_v4_concept_schemes_path

          assert_response :success
          assert_equal(response.content_type, 'application/json')

          json_data = JSON.parse(response.body)
          assert_equal(@trees, json_data['@graph'].size)
          assert(json_data['@graph'].size.positive?)
          assert_equal(@trees, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          validator = DataCycleCore::V4::Validation::Concept.concept_scheme
          json_data['@graph'].each do |item|
            assert_equal({}, validator.call(item).errors.to_h)
          end
        end

        test 'api/v4/concept_schemes with fields=dct:modified' do
          post api_v4_concept_schemes_path(fields: 'dc:entityUrl')

          assert_response :success
          assert_equal(response.content_type, 'application/json')

          json_data = JSON.parse(response.body)
          assert_equal(@trees, json_data['@graph'].size)
          assert(json_data['@graph'].size.positive?)
          assert_equal(@trees, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          fields = Dry::Schema.JSON do
            required(:'dc:entityUrl').value(:string)
          end

          validator = DataCycleCore::V4::Validation::Concept.concept_scheme(params: { fields: fields })
          json_data['@graph'].each do |item|
            assert_equal({}, validator.call(item).errors.to_h)
          end
        end

        test 'api/v4/concept_schemes/(:id)' do
          tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
          post api_v4_concept_scheme_path(id: tree.id)

          assert_response :success
          assert_equal(response.content_type, 'application/json')

          json_data = JSON.parse(response.body)
          assert_equal(1, json_data['@graph'].size)

          validator = DataCycleCore::V4::Validation::Concept.concept_scheme
          json_data['@graph'].each do |item|
            assert_equal({}, validator.call(item).errors.to_h)
          end
        end

        test 'api/v4/concept_schemes/(:id) with fields=dc:entityUrl,dc:hasConcept' do
          tree = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
          post_params = {
            id: tree.id,
            fields: 'dc:entityUrl,dc:hasConcept'
          }
          post api_v4_concept_scheme_path(post_params)

          assert_response :success
          assert_equal(response.content_type, 'application/json')

          json_data = JSON.parse(response.body)
          assert_equal(1, json_data['@graph'].size)

          fields = Dry::Schema.JSON do
            required(:'dc:entityUrl').value(:string)
            required(:'dc:hasConcept').value(:string)
          end

          validator = DataCycleCore::V4::Validation::Concept.concept_scheme(params: { fields: fields })
          json_data['@graph'].each do |item|
            assert_equal({}, validator.call(item).errors.to_h)
          end
        end

        test 'api/v4/concept_schemes/(:id)/concepts' do
          tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
          classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
          params = {
            id: tree_id
          }
          post classifications_api_v4_concept_scheme_path(params)

          assert_response :success
          assert_equal(response.content_type, 'application/json')

          json_data = JSON.parse(response.body)
          assert_equal(classifications, json_data['@graph'].size)
          assert_equal(classifications, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          validator = DataCycleCore::V4::Validation::Concept.concept
          json_data['@graph'].each do |item|
            assert_equal({}, validator.call(item).errors.to_h)
          end
        end

        test 'api/v4/concept_schemes/(:id)/concepts fields skos:prefLabel,dct:description,dct:modified' do
          tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
          classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
          params = {
            id: tree_id,
            fields: 'skos:prefLabel,dct:description,dct:modified'
          }
          post classifications_api_v4_concept_scheme_path(params)

          assert_response :success
          assert_equal(response.content_type, 'application/json')

          json_data = JSON.parse(response.body)
          assert_equal(classifications, json_data['@graph'].size)
          assert_equal(classifications, json_data['meta']['total'].to_i)
          assert_equal(true, json_data.key?('links'))

          fields = Dry::Schema.JSON do
            required(:'skos:prefLabel').value(:string)
            optional(:'dct:description').value(:string)
            required(:'dct:modified').value(:date_time)
          end

          validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
          json_data['@graph'].each do |item|
            assert_equal({}, validator.call(item).errors.to_h)
          end
        end

        #################  TODO: validate
        # http://localhost:3010/api/v4/things/11eafb48-1629-4484-8e46-e3a5647abaf2?include=offers&fields=offers.name
        # localhost:3010/api/v4/concept_schemes/6aa5415c-4771-4dec-a180-ff3e7364ca54/concepts?fields=skos:inScheme
        # http://localhost:3010/api/v4/things/11eafb48-1629-4484-8e46-e3a5647abaf2?fields=dc:classification.skos:inScheme
        #
        # INCLUDE
        # test 'concepts at /api/v4/things/:id with include dc:classification,dc:classification.skos:inScheme' do
        #   get api_v4_thing_path(id: @content.id, include: 'dc:classification,dc:classification.skos:inScheme')
        #   assert_response :success
        #
        #   assert_equal(response.content_type, 'application/json')
        #   json_data = JSON.parse response.body
        #
        #   header = json_data.slice(*full_header_attributes)
        #   data = full_header_data(@content)
        #   assert_equal(header, data)
        #
        #   assert_concept_attributes(json_data.dig('dc:classification', 0))
        #   json_data.dig('dc:classification', 0).slice(*embedded_concept_attributes).each do |embedded_attribute|
        #     assert_compact_header(Array(json_data.dig('dc:classification', 0, embedded_attribute)))
        #   end
        #
        #   assert_concept_attributes(json_data.dig('dc:classification', 0, 'skos:inScheme'))
        # end
        #
        # test 'include dc:classification,dc:classification.skos:inScheme is equal to include dc:classification.skos:inScheme' do
        #   get api_v4_thing_path(id: @content.id, include: 'dc:classification,dc:classification.skos:inScheme')
        #   assert_response :success
        #   assert_equal(response.content_type, 'application/json')
        #   json_data = JSON.parse response.body
        #
        #   get api_v4_thing_path(id: @content.id, include: 'dc:classification.skos:inScheme')
        #   assert_response :success
        #   assert_equal(response.content_type, 'application/json')
        #   json_data2 = JSON.parse response.body
        #   assert_equal(json_data, json_data2)
        # end

        # test 'combo of fields, include' do
        #   get api_v4_thing_path(id: @content.id, fields: 'dc:classification.skos:inScheme.skos:prefLabel', include: 'dc:classification')
        #   assert_response :success
        #   assert_equal(response.content_type, 'application/json')
        #   json_data = JSON.parse response.body
        #
        #   assert_equal(1, json_data.dig('dc:classification').size)
        #   assert_concept_attributes(json_data.dig('dc:classification', 0))
        #   json_data.dig('dc:classification', 0).slice(*embedded_concept_attributes).each do |embedded_attribute|
        #     assert_compact_header(Array(json_data.dig('dc:classification', 0, embedded_attribute)))
        #   end
        #   assert_equal(['@id', '@type', 'skos:prefLabel'], json_data.dig('dc:classification', 0, 'skos:inScheme').keys)
        # end
      end
    end
  end
end
