# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Sort
        class RandomTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
            @routes = Engine.routes

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @poi_c = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @poi_d = DataCycleCore::V4::DummyDataHelper.create_data('poi')

            @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').count
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'api/v4/things with parameter sort: random' do
            # default no sorting
            params = {
              fields: 'name'
            }
            post api_v4_things_path(params)
            json_data = response.parsed_body
            orig = json_data.dig('@graph').pluck('@id')

            # random
            params = {
              fields: 'name',
              sort: 'random'
            }

            100.times do
              post api_v4_things_path(params)
              json_data = response.parsed_body
              t = json_data.dig('@graph').pluck('@id')

              assert_not_equal(t, orig)
            end
          end

          test 'api/v4/things with parameter sort: random with seed' do
            params = {
              fields: 'name',
              sort: 'random(0.63345345)'
            }

            post api_v4_things_path(params)
            json_data = response.parsed_body

            orig = json_data.dig('@graph').pluck('@id')

            100.times do
              post api_v4_things_path(params)
              json_data = response.parsed_body
              t = json_data.dig('@graph').pluck('@id')
              assert_equal(t, orig)
            end
          end
        end
      end
    end
  end
end
