# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class CreatorTest < DataCycleCore::V4::Base
          before(:all) do
            @creator = User.find_by(email: 'tester@datacycle.at')
            @admin = User.find_by(email: 'admin@datacycle.at')
            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi', @creator)
            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi', @creator)
            @food_establishment_a = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment', @admin)
            @food_establishment_b = DataCycleCore::V4::DummyDataHelper.create_data('food_establishment', @creator)
            @thing_count = DataCycleCore::Thing.where.not(content_type: 'embedded').size
          end

          test 'api/v4/things parameter filter[creator]' do
            params = {}
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            params = {
              filter: {
                creator: {
                  in: [
                    @creator.id
                  ]
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(DataCycleCore::Thing.where(created_by: @creator).size)

            params = {
              filter: {
                creator: {
                  in: [
                    @admin.id
                  ]
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(DataCycleCore::Thing.where(created_by: @admin).size)

            params = {
              filter: {
                creator: {
                  notIn: [
                    @admin.id
                  ]
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(DataCycleCore::Thing.where(created_by: @creator).size)

            params = {
              filter: {
                creator: {
                  in: [
                    "#{@admin.id},#{@creator.id}"
                  ]
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            params = {
              filter: {
                creator: {
                  notIn: [
                    @admin.id,
                    @creator.id
                  ]
                }
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(0)
          end
        end
      end
    end
  end
end
