# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class SearchTest < DataCycleCore::V4::Base
          setup do
            DataCycleCore::Thing.where(template: false).delete_all

            @event = DataCycleCore::V4::DummyDataHelper.create_data('event')
            @poi = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @poi.set_data_hash(partial_update: true, prevent_history: true, data_hash: { name: 'Headline POI' })

            @thing_count = DataCycleCore::Thing.where(template: false).where.not(content_type: 'embedded').count
          end

          test 'api/v4/things parameter filter search' do
            params = {}
            post api_v4_things_path(params)
            assert_api_count_result(@thing_count)

            # find all events
            params = {
              filter: {
                search: ''
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(8)

            params = {
              filter: {
                search: 'Headline'
              }
            }
            post api_v4_things_path(params)
            assert_api_count_result(2)
          end
        end
      end
    end
  end
end
