# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class GraphFilterTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all

            @routes = Engine.routes

            @user = User.find_by(email: 'tester@datacycle.at')

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @poi_c = DataCycleCore::V4::DummyDataHelper.create_data('poi')

            @image = DataCycleCore::V4::DummyDataHelper.create_data('image')

            DataCycleCore::ContentContent.create(content_a_id: @poi_a.id, content_b_id: @image.id, relation_a: 'image')
            DataCycleCore::ContentContent.create(content_a_id: @poi_a.id, content_b_id: @poi_b.id, relation_a: 'content_location')

            @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')

            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @poi_a.id, hashable_type: @poi_a.class.name)
            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @poi_c.id, hashable_type: @poi_c.class.name)

            @empty_filter = add_fulltext_filter('???????????????')

            @stored_filter = add_fulltext_filter(@poi_b.name)
          end

          def add_a_b_graph_filter(relation_type = nil, base_filter = nil)
            base_filter = DataCycleCore::StoredFilter.create(user_id: @user.id) if base_filter.nil?

            DataCycleCore::StoredFilter.create(
              name: 'graph_filter',
              user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
              language: ['de'],
              parameters: [
                {'c' => 'a', 'm' => 'i', 'n' => 'items_linked_to', 'q' => 'graph_filter', 't' => 'graph_filter', 'v' => {'filter' => base_filter.id, 'relation_type' => relation_type}}
              ],
              sort_parameters: [
                {'m' => 'default'}
              ],
              api: true
            )
          end

          def add_b_a_graph_filter(relation_type = nil, base_filter = nil)
            @user = User.find_by(email: 'tester@datacycle.at')
            base_filter = DataCycleCore::StoredFilter.create(user_id: @user.id) if base_filter.nil?

            DataCycleCore::StoredFilter.create(
              name: 'graph_filter',
              user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
              language: ['de'],
              parameters: [
                {'c' => 'a', 'm' => 'i', 'n' => 'linked_items_in', 'q' => 'graph_filter', 't' => 'graph_filter', 'v' => {'filter' => base_filter.id, 'relation_type' => relation_type}}
              ],
              sort_parameters: [
                {'m' => 'default'}
              ],
              api: true
            )
          end

          def add_fulltext_filter(string)
            DataCycleCore::StoredFilter.create(
              name: 'fulltext',
              user_id: @user.id,
              language: ['de'],
              parameters: [{
                'n' => 'Suchbegriff',
                't' => 'fulltext_search',
                'v' => string
              }],
              sort_parameters: [{
                'v' => string,
                'm' => 'fulltext_search',
                'o' => 'DESC'
              }],
              api: true
            )
          end

          test 'api/v4/things without any filter - for reference' do
            post_params = {}
            post api_v4_things_path(post_params)

            assert_api_count_result(7)
          end

          test 'api/v4/things with filter[graph_filter][linked_items_in] - content_location' do
            # test without base filter
            graph_filter = add_b_a_graph_filter('linked_location;content_location')
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(1)

            # test with watch_list as base filter
            graph_filter = add_b_a_graph_filter('linked_location;content_location', @watch_list)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(1)

            # test with empty stored_filter as base filter
            graph_filter = add_b_a_graph_filter('linked_location;content_location', @empty_filter)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with stored_filter as base filter
            graph_filter = add_b_a_graph_filter('linked_location;content_location', @stored_filter)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)
          end

          test 'api/v4/things with filter[graph_filter][items_linked_to] - content_location' do
            # test without base filter
            graph_filter = add_a_b_graph_filter('linked_location;content_location')
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(1)

            # test with watch_list as base filter
            graph_filter = add_a_b_graph_filter('linked_location;content_location', @watch_list)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with empty stored_filter as base filter
            graph_filter = add_a_b_graph_filter('linked_location;content_location', @empty_filter)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with stored_filter as base filter
            graph_filter = add_a_b_graph_filter('linked_location;content_location', @stored_filter)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(1)
          end

          test 'api/v4/things with filter[graph_filter][linked_items_in] - image' do
            # test without base filter
            graph_filter = add_b_a_graph_filter('linked_image;image')
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(4) # 4 items - 3 linked automatically by dummy data, another one set up via content content

            # test with watch_list as base filter
            graph_filter = add_b_a_graph_filter('linked_image;image', @watch_list)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(3) # 3 items - 2 linked automatically by dummy data, another one set up via content content

            # test with empty stored_filter as base filter
            graph_filter = add_b_a_graph_filter('linked_image;image', @empty_filter)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with stored_filter as base filter
            graph_filter = add_b_a_graph_filter('linked_image;image', @stored_filter)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(1)
          end

          test 'api/v4/things with filter[graph_filter][items_linked_to] - image' do
            # test without base filter
            graph_filter = add_a_b_graph_filter('linked_image;image')
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(3) # 3 items - 2 linked automatically by dummy data, another one set up via content content

            # test with watch_list as base filter
            graph_filter = add_a_b_graph_filter('linked_image;image', @watch_list)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with empty stored_filter as base filter
            graph_filter = add_a_b_graph_filter('linked_image;image', @empty_filter)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with stored_filter as base filter
            graph_filter = add_a_b_graph_filter('linked_image;image', @stored_filter)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)
          end
        end
      end
    end
  end
end
