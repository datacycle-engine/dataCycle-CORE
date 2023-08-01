# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Classifications
        class ClassificationSortTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
            @trees = DataCycleCore::ClassificationTreeLabel.where(internal: false).visible('api').count
          end

          # TODO: add context test
          test 'api/v4/concept_schemes parameter sort: created' do
            tree_tags = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            orig_ts = tree_tags.created_at

            tree_tags.update_column(:created_at, (Time.zone.now + 10.days))

            # DESC
            params = {
              sort: '-dct:created',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_equal(tree_tags.id, json_data.dig('@graph').first.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:created').to_datetime >= b.dig('dct:created').to_datetime)
            end

            # ASC
            params = {
              sort: '+dct:created',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_equal(tree_tags.id, json_data.dig('@graph').last.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:created').to_datetime <= b.dig('dct:created').to_datetime)
            end

            # make sure ASC is default
            params = {
              sort: 'dct:created',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_equal(tree_tags.id, json_data.dig('@graph').last.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:created').to_datetime <= b.dig('dct:created').to_datetime)
            end
            tree_tags.update_column(:created_at, orig_ts)
          end

          # order by modified
          test 'api/v4/concept_schemes parameter sort: modified' do
            tree_tags = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            orig_ts = tree_tags.updated_at

            # DESC
            tree_tags.update_column(:updated_at, (Time.zone.now + 10.days))
            params = {
              sort: '-dct:modified',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_equal(tree_tags.id, json_data.dig('@graph').first.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime >= b.dig('dct:modified').to_datetime)
            end

            # ASC
            params = {
              sort: '+dct:modified',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_equal(tree_tags.id, json_data.dig('@graph').last.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime <= b.dig('dct:modified').to_datetime)
            end

            # make sure ASC is default
            params = {
              sort: 'dct:modified',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_equal(tree_tags.id, json_data.dig('@graph').last.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime <= b.dig('dct:modified').to_datetime)
            end

            # make sure modified DESC is default for empty sort params
            params = {
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_equal(tree_tags.id, json_data.dig('@graph').first.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime >= b.dig('dct:modified').to_datetime)
            end
            tree_tags.update_column(:updated_at, orig_ts)
          end

          test 'api/v4/concept_schemes parameter multiple and invalid sort params' do
            tree_tags = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags')
            orig_ts = tree_tags.created_at

            tree_tags.update_column(:created_at, (Time.zone.now + 10.days))
            params = {
              sort: '-dct:created,+dct:modified,+another',
              page: {
                size: 100
              }
            }
            post api_v4_concept_schemes_path(params)
            assert_api_count_result(@trees)

            json_data = JSON.parse(response.body)
            assert_equal(tree_tags.id, json_data.dig('@graph').first.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:created').to_datetime >= b.dig('dct:created').to_datetime)
            end
            tree_tags.update_column(:created_at, orig_ts)
          end

          test 'api/v4/concept_schemes/id/concepts parameter sort[:modified]' do
            tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id
            classifications = DataCycleCore::ClassificationAlias.for_tree('Tags')
            classifications_count = classifications.count
            classificaton_tag = classifications.with_name('Tag 3').first
            orig_ts = classificaton_tag.updated_at

            classificaton_tag.update_column(:updated_at, (Time.zone.now + 10.days))

            # modified ASC
            params = {
              id: tree_id,
              sort: 'dct:modified',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications_count)

            json_data = JSON.parse(response.body)
            assert_equal(classificaton_tag.id, json_data.dig('@graph').last.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime <= b.dig('dct:modified').to_datetime)
            end

            # modified ASC
            params = {
              id: tree_id,
              sort: '+dct:modified',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications_count)

            json_data = JSON.parse(response.body)
            assert_equal(classificaton_tag.id, json_data.dig('@graph').last.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime <= b.dig('dct:modified').to_datetime)
            end

            # modified DESC
            params = {
              id: tree_id,
              sort: '-dct:modified',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications_count)

            json_data = JSON.parse(response.body)
            assert_equal(classificaton_tag.id, json_data.dig('@graph').first.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime >= b.dig('dct:modified').to_datetime)
            end

            # make sure default is order_a ASC
            params = {
              id: tree_id,
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications_count)

            json_data = JSON.parse(response.body)
            assert_equal(classifications.first.id, json_data.dig('@graph').first.dig('@id'))

            classification_mappings = classifications.index_by(&:id)

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(classification_mappings[a['@id']].order_a < classification_mappings[b['@id']].order_a)
            end

            # muliple and invalid sort params
            params = {
              id: tree_id,
              sort: '-dct:modified,+dct:created,+another,++another2',
              page: {
                size: 100
              }
            }
            post classifications_api_v4_concept_scheme_path(params)
            assert_api_count_result(classifications_count)

            json_data = JSON.parse(response.body)
            assert_equal(classificaton_tag.id, json_data.dig('@graph').first.dig('@id'))

            json_data.dig('@graph').each_cons(2) do |a, b|
              assert(a.dig('dct:modified').to_datetime >= b.dig('dct:modified').to_datetime)
            end

            classificaton_tag.update_column(:updated_at, orig_ts)
          end
        end
      end
    end
  end
end
