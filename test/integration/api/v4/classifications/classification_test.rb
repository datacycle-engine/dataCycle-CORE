# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationTest < DataCycleCore::V4::Base
          setup do
            DataCycleCore::Thing.where(template: false).delete_all
            @trees = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('api').count
          end

          test 'api/v4/concept_schemes' do
            post api_v4_concept_schemes_path

            assert_api_count_result(@trees)
            json_data = JSON.parse(response.body)

            validator = DataCycleCore::V4::Validation::Concept.concept_scheme
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          # test with fields / linked not working for concept_schemes
          test 'api/v4/concept_schemes with fields=dct:modified' do
            post api_v4_concept_schemes_path(fields: 'dc:entityUrl')

            assert_api_count_result(@trees)
            json_data = JSON.parse(response.body)

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

            validator = DataCycleCore::V4::Validation::Concept.concept_scheme
            assert_equal({}, validator.call(json_data.except('@context')).errors.to_h)
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

            fields = Dry::Schema.JSON do
              required(:'dc:entityUrl').value(:string)
              required(:'dc:hasConcept').value(:string)
            end

            validator = DataCycleCore::V4::Validation::Concept.concept_scheme(params: { fields: fields })
            assert_equal({}, validator.call(json_data.except('@context')).errors.to_h)
          end

          test 'api/v4/concept_schemes/(:id)/concepts' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = JSON.parse(response.body)

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

            assert_api_count_result(classifications)
            json_data = JSON.parse(response.body)

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

          test 'api/v4/concept_schemes/(:id)/concepts/(:classification_id) fields identifier for external concepts' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id

            update_tag = DataCycleCore::ClassificationAlias.for_tree('Tags').with_name('Tag 3').first
            external_source_id = DataCycleCore::ExternalSource.first.id
            update_tag.update_column(:external_source_id, external_source_id) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_source_id, external_source_id) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_key, 'test-identifier') # rubocop:disable Rails/SkipsModelValidations

            params = {
              id: tree_id,
              classification_id: update_tag.id,
              fields: 'skos:prefLabel,dct:description,dct:modified,identifier'
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_response :success
            assert_equal(response.content_type, 'application/json')

            json_data = JSON.parse(response.body)

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
              optional(:'dct:description').value(:string)
              required(:'dct:modified').value(:date_time)
              required(:identifier).value(:array).each do
                hash(DataCycleCore::V4::Validation::Concept::IDENTIFIER_ATTRIBUTES)
              end
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            assert_equal({}, validator.call(json_data.except('@context')).errors.to_h)
            assert_equal('test-identifier', json_data.dig('identifier').first.dig('value'))

            update_tag.update_column(:external_source_id, nil) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_source_id, nil) # rubocop:disable Rails/SkipsModelValidations
            update_tag.primary_classification.update_column(:external_key, nil) # rubocop:disable Rails/SkipsModelValidations
          end

          # TODO: fields for relation without relation attirbute name MUST return minimal header
          test 'api/v4/concept_schemes/(:id)/concepts fields skos:inScheme' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              fields: 'skos:inScheme'
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = JSON.parse(response.body)

            fields = Dry::Schema.JSON do
              required(:'skos:inScheme').hash(DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER)
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          # TODO: fields for relation with relation attribute name MUST return DEFAULT_HEADER + Attribute
          test 'api/v4/concept_schemes/(:id)/concepts fields skos:inScheme,skos:inScheme.skos:prefLabel' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              fields: 'skos:inScheme,skos:inScheme.skos:prefLabel'
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = JSON.parse(response.body)

            fields = Dry::Schema.JSON do
              required(:'skos:inScheme').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  Dry::Schema.JSON do
                    required(:'skos:prefLabel').value(:string)
                  end
                )
              )
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          # TODO: fields for relation with relation attribute name MUST return DEFAULT_HEADER + Attribute
          test 'api/v4/concept_schemes/(:id)/concepts fields skos:inScheme.skos:prefLabel' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              fields: 'skos:inScheme.skos:prefLabel'
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = JSON.parse(response.body)

            fields = Dry::Schema.JSON do
              required(:'skos:inScheme').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  Dry::Schema.JSON do
                    required(:'skos:prefLabel').value(:string)
                  end
                )
              )
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          # TODO: nested fields for relation with relation attribute name MUST return DEFAULT_HEADER + Attribute for main + nested
          test 'api/v4/concept_schemes/(:id)/concepts fields skos:broader.skos:inScheme.skos:prefLabel' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              fields: 'skos:broader.skos:inScheme.skos:prefLabel'
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = JSON.parse(response.body)

            fields = Dry::Schema.JSON do
              optional(:'skos:broader').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  Dry::Schema.JSON do
                    optional(:'skos:inScheme').hash(
                      DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                        Dry::Schema.JSON do
                          required(:'skos:prefLabel').value(:string)
                        end
                      )
                    )
                  end
                )
              )
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          # TODO: include for relation  MUST return DEFAULT_HEADER + DEFAULT_ATTRIBUTES
          test 'api/v4/concept_schemes/(:id)/concepts include skos:inScheme' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              include: 'skos:inScheme'
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = JSON.parse(response.body)

            include = Dry::Schema.JSON do
              required(:'skos:inScheme').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  DataCycleCore::V4::Validation::Concept::DEFAULT_CONCEPT_SCHEME_ATTRIBUTES
                )
              )
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { include: include })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          # TODO: nested include for relation  MUST return DEFAULT_HEADER + DEFAULT_ATTRIBUTES for entry + nested
          test 'api/v4/concept_schemes/(:id)/concepts include skos:broader.skos:inScheme' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              include: 'skos:broader.skos:inScheme'
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = JSON.parse(response.body)

            include = Dry::Schema.JSON do
              optional(:'skos:broader').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  DataCycleCore::V4::Validation::Concept::DEFAULT_CONCEPT_ATTRIBUTES.merge(
                    Dry::Schema.JSON do
                      optional(:'skos:inScheme').hash(
                        DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                          DataCycleCore::V4::Validation::Concept::DEFAULT_CONCEPT_SCHEME_ATTRIBUTES
                        )
                      )
                    end
                  )
                )
              )
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { include: include })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          # TODO: include for relation  MUST return DEFAULT_HEADER + DEFAULT_ATTRIBUTES
          test 'api/v4/concept_schemes/(:id)/concepts include skos:ancestors' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              include: 'skos:ancestors'
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = JSON.parse(response.body)

            include = Dry::Schema.JSON do
              optional(:'skos:ancestors').value(:array).each do
                hash(
                  DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                    DataCycleCore::V4::Validation::Concept::DEFAULT_CONCEPT_ATTRIBUTES
                  )
                )
              end
            end
            validator = DataCycleCore::V4::Validation::Concept.concept(params: { include: include })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          # TODO: include MUST NOT return anything if fields are use
          test 'api/v4/concept_schemes/(:id)/concepts include skos:ancestors fields skos:prefLabel' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              include: 'skos:ancestors',
              fields: 'skos:prefLabel'
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = JSON.parse(response.body)

            fields = Dry::Schema.JSON do
              required(:'skos:prefLabel').value(:string)
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end

          # TODO: include MUST NOT return anything if fields are use
          test 'api/v4/concept_schemes/(:id)/concepts include skos:inScheme fields skos:inScheme.skos:prefLabel' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags').count
            params = {
              id: tree_id,
              include: 'skos:inScheme',
              fields: 'skos:inScheme.skos:prefLabel'
            }
            post classifications_api_v4_concept_scheme_path(params)

            assert_api_count_result(classifications)
            json_data = JSON.parse(response.body)

            fields = Dry::Schema.JSON do
              required(:'skos:inScheme').hash(
                DataCycleCore::V4::Validation::Concept::DEFAULT_HEADER.merge(
                  Dry::Schema.JSON do
                    required(:'skos:prefLabel').value(:string)
                  end
                )
              )
            end

            validator = DataCycleCore::V4::Validation::Concept.concept(params: { fields: fields })
            json_data['@graph'].each do |item|
              assert_equal({}, validator.call(item).errors.to_h)
            end
          end
        end
      end
    end
  end
end
