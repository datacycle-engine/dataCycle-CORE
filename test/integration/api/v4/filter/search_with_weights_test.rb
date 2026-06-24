# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class SearchWithWeightsTest < DataCycleCore::V4::Base
          before(:all) do
            @ts_query_before_state = DataCycleCore.features[:ts_query_fulltext_search].deep_dup
            DataCycleCore.features[:ts_query_fulltext_search][:enabled] = true
            Feature::TsQueryFulltextSearch.reload

            DataCycleCore::Thing.delete_all

            # name: Headline used for event, event_series and poi
            @event = DataCycleCore::V4::DummyDataHelper.create_data('event')
            @poi = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @poi.set_data_hash(partial_update: true, prevent_history: true, data_hash: { name: 'Headline POI', slug: 'headline-tourist-attraction' })
          end

          after(:all) do
            DataCycleCore.features = DataCycleCore.features.except(:ts_query_fulltext_search)
              .merge({ ts_query_fulltext_search: @ts_query_before_state })
            Feature::TsQueryFulltextSearch.reload
          end

          test 'api/v4/things parameter filter ts_query search' do
            params = {
              filter: {
                search: 'Headline'
              }
            }
            post api_v4_things_path(params)

            assert_api_count_result(3)
          end

          test 'api/v4/things parameter filter ts_query search and weights' do
            params = {
              filter: {
                search: {
                  value: 'Headline',
                  fields: 'name'
                }
              }
            }
            post api_v4_things_path(params)

            assert_api_count_result(3)

            params = {
              filter: {
                search: {
                  value: 'Headline',
                  fields: 'dc:slug'
                }
              }
            }
            post api_v4_things_path(params)

            assert_api_count_result(3)

            params = {
              filter: {
                search: {
                  value: 'tourist',
                  fields: 'dc:slug'
                }
              }
            }
            post api_v4_things_path(params)

            assert_api_count_result(1)

            params = {
              filter: {
                search: {
                  value: 'tourist',
                  fields: 'dc:classification'
                }
              }
            }
            post api_v4_things_path(params)

            assert_api_count_result(0)
          end

          test 'api/v4/things parameter filter ts_query q and weights' do
            params = {
              filter: {
                q: {
                  value: 'Headline',
                  fields: 'name'
                }
              }
            }
            post api_v4_things_path(params)

            assert_api_count_result(3)

            params = {
              filter: {
                q: {
                  value: 'Headline',
                  fields: 'dc:slug'
                }
              }
            }
            post api_v4_things_path(params)

            assert_api_count_result(3)

            params = {
              filter: {
                q: {
                  value: 'tourist',
                  fields: 'dc:slug'
                }
              }
            }
            post api_v4_things_path(params)

            assert_api_count_result(1)

            params = {
              filter: {
                q: {
                  value: 'tourist',
                  fields: 'dc:classification'
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
