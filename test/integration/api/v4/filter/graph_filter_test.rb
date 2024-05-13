# frozen_string_literal: true

require 'v4/base'

module DataCycleCore
  module Api
    module V4
      module Filter
        class GraphFilterTest < DataCycleCore::V4::Base
          before(:all) do
            DataCycleCore::Thing.delete_all
            DataCycleCore::ContentContent.delete_all
            DataCycleCore::ContentContent::Link.delete_all

            @routes = Engine.routes

            @user = User.find_by(email: 'tester@datacycle.at')
            # @user = User.find_by(email: 'admin@datacycle.at')

            @poi_a = DataCycleCore::V4::DummyDataHelper.create_data('poi')
            @poi_b = DataCycleCore::V4::DummyDataHelper.create_data('poi')

            @image = DataCycleCore::V4::DummyDataHelper.create_data('image')

            DataCycleCore::ContentContent.create(content_a_id: @poi_a.id, content_b_id: @image.id, relation_a: 'image')
            DataCycleCore::ContentContent.create(content_a_id: @poi_a.id, content_b_id: @poi_b.id, relation_a: 'content_location')

            @watch_list = DataCycleCore::TestPreparations.create_watch_list(name: 'TestWatchList')

            DataCycleCore::WatchListDataHash.find_or_create_by(watch_list_id: @watch_list.id, hashable_id: @poi_a.id, hashable_type: @poi_a.class.name)

            # fulltext search stored filter that should have no results
            @empty_filter = add_fulltext_filter('???????????????')

            # fulltext search stored filter filtering for name of @poi_b, should return only @poi_b - Linked: 2 images, no poi
            @stored_filter = add_fulltext_filter(@poi_b.name)
          end

          setup do
            sign_in(@user)
          end

          teardown do
            DataCycleCore::Thing.delete_all
            DataCycleCore::ContentContent.delete_all
            DataCycleCore::ContentContent::Link.delete_all
          end

          # basic test
          test 'api/v4/things without any filter - for reference' do
            post_params = {}
            post api_v4_things_path(post_params)

            assert_api_count_result(5)
          end

          # relation_type based filter tests:
          test 'api/v4/things with filter[graph_filter][items_linked_to] - relation_type based - content_location' do
            # test without base filter
            graph_filter = add_a_b_graph_filter(nil, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(1)

            # test with watch_list as base filter
            graph_filter = add_a_b_graph_filter(@watch_list, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(1)

            # test with empty stored_filter as base filter
            graph_filter = add_a_b_graph_filter(@empty_filter, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with stored_filter as base filter
            graph_filter = add_a_b_graph_filter(@stored_filter, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)
          end

          test 'api/v4/things without filter[graph_filter][items_linked_to] - relation_type based - content_location' do
            # test without base filter
            graph_filter = not_add_a_b_graph_filter(nil, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(4)

            # test with watch_list as base filter
            graph_filter = not_add_a_b_graph_filter(@watch_list, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(5)

            # test with empty stored_filter as base filter
            graph_filter = not_add_a_b_graph_filter(@empty_filter, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(5)

            # test with stored_filter as base filter
            graph_filter = not_add_a_b_graph_filter(@stored_filter, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(4)
          end

          test 'api/v4/things with filter[graph_filter][linked_items_in] - relation_type based - content_location' do
            # test without base filter
            graph_filter = add_b_a_graph_filter(nil, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(1)

            # test with watch_list as base filter
            graph_filter = add_b_a_graph_filter(@watch_list, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with empty stored_filter as base filter
            graph_filter = add_b_a_graph_filter(@empty_filter, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with stored_filter as base filter
            graph_filter = add_b_a_graph_filter(@stored_filter, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(1)
          end

          test 'api/v4/things without filter[graph_filter][linked_items_in] - relation_type based - content_location' do
            # test without base filter
            graph_filter = not_add_b_a_graph_filter(nil, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(4)

            # test with watch_list as base filter
            graph_filter = not_add_b_a_graph_filter(@watch_list, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(5)

            # test with empty stored_filter as base filter
            graph_filter = not_add_b_a_graph_filter(@empty_filter, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(5)

            # test with stored_filter as base filter
            graph_filter = not_add_b_a_graph_filter(@stored_filter, 'content_location', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(4)
          end

          test 'api/v4/things with filter[graph_filter][items_linked_to] - relation_type based - image' do
            # test without base filter
            graph_filter = add_a_b_graph_filter(nil, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(3)

            # test with watch_list as base filter
            graph_filter = add_a_b_graph_filter(@watch_list, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(2)

            # test with empty stored_filter as base filter
            graph_filter = add_a_b_graph_filter(@empty_filter, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with stored_filter as base filter
            graph_filter = add_a_b_graph_filter(@stored_filter, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(1)
          end

          test 'api/v4/things without filter[graph_filter][items_linked_to] - relation_type based - image' do
            # test without base filter
            graph_filter = not_add_a_b_graph_filter(nil, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(3)

            # test with watch_list as base filter
            graph_filter = not_add_a_b_graph_filter(@watch_list, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(5)

            # test with empty stored_filter as base filter
            graph_filter = not_add_a_b_graph_filter(@empty_filter, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(5)

            # test with stored_filter as base filter
            graph_filter = not_add_a_b_graph_filter(@stored_filter, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(5)
          end

          test 'api/v4/things with filter[graph_filter][linked_items_in] - relation_type based - image' do
            # test without base filter
            graph_filter = add_b_a_graph_filter(nil, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(2)

            # test with watch_list as base filter
            graph_filter = add_b_a_graph_filter(@watch_list, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with empty stored_filter as base filter
            graph_filter = add_b_a_graph_filter(@empty_filter, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)

            # test with stored_filter as base filter
            graph_filter = add_b_a_graph_filter(@stored_filter, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(0)
          end

          test 'api/v4/things without filter[graph_filter][linked_items_in] - relation_type based - image' do
            # test without base filter
            graph_filter = not_add_b_a_graph_filter(nil, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(3)

            # test with watch_list as base filter
            graph_filter = not_add_b_a_graph_filter(@watch_list, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(5)

            # test with empty stored_filter as base filter
            graph_filter = not_add_b_a_graph_filter(@empty_filter, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(5)

            # test with stored_filter as base filter
            graph_filter = not_add_b_a_graph_filter(@stored_filter, 'image', nil)
            post api_v4_stored_filter_path(id: graph_filter.id)
            assert_api_count_result(5)
          end

          # content_type based filter tests:
          # test 'api/v4/things with filter[graph_filter][items_linked_to] - content_type based - Place' do
          #   # test without base filter
          #   graph_filter = add_a_b_graph_filter(nil, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(2)

          #   # test with watch_list as base filter
          #   graph_filter = add_a_b_graph_filter(@watch_list, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(1)

          #   # test with empty stored_filter as base filter
          #   graph_filter = add_a_b_graph_filter(@empty_filter, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(0)

          #   # test with stored_filter as base filter
          #   graph_filter = add_a_b_graph_filter(@stored_filter, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(1) # same place found twice => 1 search result
          # end

          # test 'api/v4/things without filter[graph_filter][items_linked_to] - content_type based - Place' do
          #   # test without base filter
          #   graph_filter = not_add_a_b_graph_filter(nil, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(0)

          #   # test with watch_list as base filter
          #   graph_filter = not_add_a_b_graph_filter(@watch_list, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(2)

          #   # test with empty stored_filter as base filter
          #   graph_filter = not_add_a_b_graph_filter(@empty_filter, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(5)

          #   # test with stored_filter as base filter
          #   graph_filter = not_add_a_b_graph_filter(@stored_filter, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(3)
          # end

          # test 'api/v4/things with filter[graph_filter][linked_items_in] - content_type based - Place' do
          #   # test without base filter
          #   graph_filter = add_b_a_graph_filter(nil, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(5)

          #   # test with watch_list as base filter
          #   graph_filter = add_b_a_graph_filter(@watch_list, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(3)

          #   # test with empty stored_filter as base filter
          #   graph_filter = add_b_a_graph_filter(@empty_filter, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(0)

          #   # test with stored_filter as base filter
          #   graph_filter = add_b_a_graph_filter(@stored_filter, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(2)
          # end

          # test 'api/v4/things without filter[graph_filter][linked_items_in] - content_type based - Place' do
          #   # test without base filter
          #   graph_filter = not_add_b_a_graph_filter(nil, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(0)

          #   # test with watch_list as base filter
          #   graph_filter = not_add_b_a_graph_filter(@watch_list, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(2)

          #   # test with empty stored_filter as base filter
          #   graph_filter = not_add_b_a_graph_filter(@empty_filter, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(5)

          #   # test with stored_filter as base filter
          #   graph_filter = not_add_b_a_graph_filter(@stored_filter, nil, 'Ort')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(3)
          # end

          # test 'api/v4/things with filter[graph_filter][linked_items_to] - content_type based - Bild' do
          #   # test without base filter
          #   graph_filter = add_a_b_graph_filter(nil, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(3)

          #   # test with watch_list as base filter
          #   graph_filter = add_a_b_graph_filter(@watch_list, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(2)

          #   # test with empty stored_filter as base filter
          #   graph_filter = add_a_b_graph_filter(@empty_filter, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(0)

          #   # test with stored_filter as base filter
          #   graph_filter = add_a_b_graph_filter(@stored_filter, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(1)
          # end

          # test 'api/v4/things without filter[graph_filter][linked_items_to] - content_type based - Bild' do
          #   # test without base filter
          #   graph_filter = not_add_a_b_graph_filter(nil, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(3)

          #   # test with watch_list as base filter
          #   graph_filter = not_add_a_b_graph_filter(@watch_list, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(5)

          #   # test with empty stored_filter as base filter
          #   graph_filter = not_add_a_b_graph_filter(@empty_filter, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(5)

          #   # test with stored_filter as base filter
          #   graph_filter = not_add_a_b_graph_filter(@stored_filter, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(5)
          # end

          # test 'api/v4/things with filter[graph_filter][linked_items_in] - content_type based - Bild' do
          #   # test without base filter
          #   graph_filter = add_b_a_graph_filter(nil, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(2)

          #   # test with watch_list as base filter
          #   graph_filter = add_b_a_graph_filter(@watch_list, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(0)

          #   # test with empty stored_filter as base filter
          #   graph_filter = add_b_a_graph_filter(@empty_filter, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(0)

          #   # test with stored_filter as base filter
          #   graph_filter = add_b_a_graph_filter(@stored_filter, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(0)
          # end

          # test 'api/v4/things without filter[graph_filter][linked_items_in] - content_type based - Bild' do
          #   # test without base filter
          #   graph_filter = not_add_b_a_graph_filter(nil, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(3)

          #   # test with watch_list as base filter
          #   graph_filter = not_add_b_a_graph_filter(@watch_list, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(5)

          #   # test with empty stored_filter as base filter
          #   graph_filter = not_add_b_a_graph_filter(@empty_filter, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(5)

          #   # test with stored_filter as base filter
          #   graph_filter = not_add_b_a_graph_filter(@stored_filter, nil, 'Bild')
          #   post api_v4_stored_filter_path(id: graph_filter.id)
          #   assert_api_count_result(5)
          # end

          # helper functions for tests
          def add_a_b_graph_filter(base_filter = nil, relation_type = nil, content_types = [])
            graph_filter(base_filter, true, false, relation_type, content_types)
          end

          def add_b_a_graph_filter(base_filter = nil, relation_type = nil, content_types = [])
            graph_filter(base_filter, false, false, relation_type, content_types)
          end

          def not_add_a_b_graph_filter(base_filter = nil, relation_type = nil, content_types = [])
            graph_filter(base_filter, false, true, relation_type, content_types)
          end

          def not_add_b_a_graph_filter(base_filter = nil, relation_type = nil, content_types = [])
            graph_filter(base_filter, false, true, relation_type, content_types)
          end

          def graph_filter(base_filter = nil, direction_a_b = true, exclude_filter = false, relation_type = nil, _content_types = [])
            # class_aliases = content_type_list_to_classification_aliases(content_types)

            m_val = exclude_filter ? 'e' : 'i'
            n_val = direction_a_b ? 'items_linked_to' : 'linked_items_in'

            DataCycleCore::StoredFilter.create(
              name: 'graph_filter',
              user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id,
              language: ['de'],
              parameters: [
                {
                  'c' => 'a',
                  'm' => m_val,
                  'n' => n_val,
                  'q' => relation_type,
                  't' => 'graph_filter',
                  'v' => base_filter&.id
                }
              ],
              sort_parameters: [
                {'m' => 'default'}
              ],
              api: true
            )
          end

          def content_type_list_to_classification_aliases(content_type_names = [])
            content_type_names = [] if content_type_names.nil?
            content_type_names = [content_type_names] unless content_type_names.is_a?(Array)
            DataCycleCore::ClassificationAlias.where(internal_name: content_type_names).map(&:id)
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
        end
      end
    end
  end
end
