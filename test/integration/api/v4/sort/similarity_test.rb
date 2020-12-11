# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Sort
        class SimilarityTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.where(template: false).delete_all
            @routes = Engine.routes

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            @poi_a.set_data_hash(partial_update: true, prevent_history: true, data_hash: { name: 'aaaaaa - headline' })
            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            @poi_b.set_data_hash(partial_update: true, prevent_history: true, data_hash: { name: 'aaabbb - headline' })
            @poi_c = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            @poi_c.set_data_hash(partial_update: true, prevent_history: true, data_hash: { name: 'ddd - headline' })
            @poi_d = DataCycleCore::V4::DummyDataHelper.create_data('minimal_poi')
            @poi_d.set_data_hash(partial_update: true, prevent_history: true, data_hash: { name: 'ccc - headline' })

            @thing_count = DataCycleCore::Thing.where(template: false).where.not(content_type: 'embedded').count
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'api/v4/things with parameter sort: name with fullt text search' do
            # default no sorting
            params = {
              fields: 'name',
              filter: {
                q: 'headline'
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            # Default sorting for similarity is used with full text search
            params = {
              fields: 'name',
              filter: {
                q: 'aaa'
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = JSON.parse(response.body)
            assert_equal(@poi_a.id, json_data.dig('@graph').first.dig('@id'))

            # ASC
            params = {
              fields: 'name',
              sort: '+similarity',
              filter: {
                q: 'aaa'
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = JSON.parse(response.body)
            assert_equal(@poi_b.id, json_data.dig('@graph').first.dig('@id'))

            # ASC
            params = {
              fields: 'name',
              sort: 'similarity',
              filter: {
                q: 'aaa'
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = JSON.parse(response.body)
            assert_equal(@poi_b.id, json_data.dig('@graph').first.dig('@id'))

            # DESC
            params = {
              fields: 'name',
              sort: '-similarity',
              filter: {
                q: 'aaa'
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)

            json_data = JSON.parse(response.body)
            assert_equal(@poi_a.id, json_data.dig('@graph').first.dig('@id'))
          end
        end
      end
    end
  end
end
