# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class LinkedTest < DataCycleCore::TestCases::ActiveSupportTestCase
        include DataCycleCore::DataHelper

        before(:all) do
          # create entity and add 5 linked entities from the same table
          @things_before = DataCycleCore::Thing.count
          linked_size = 5
          @linked_objects = []

          count_things(diff: [linked_size, 0, 0, 0]) do
            linked_size.times do |i|
              @linked_objects.push(DataCycleCore::TestPreparations.create_content(template_name: 'Linked-Creative-Work-2', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge({ 'name' => "CreativeWork Linked Headline #{i}" }), prevent_history: true).id)
            end
          end

          count_things(diff: [1, 0, 0, 0]) do
            @data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Linked-Creative-Work-1', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked'), prevent_history: true)
          end

          count_things(diff: [0, 0, 5, 0]) do
            @data_set.set_data_hash(
              data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
                {
                  'linked_creative_work' => @linked_objects
                }
              ),
              partial_update: true
            )
            @data_set.save
          end

          assert_equal true, @data_set.write_history
        end

        test 'read linked data, filter linked data' do
          linked = @data_set.linked_creative_work.first
          linked.set_data_hash(data_hash: linked.get_data_hash.merge({ 'name' => 'test' }), prevent_history: true)

          linked_filter = DataCycleCore::StoredFilter.create(
            name: 'fulltext',
            user_id: DataCycleCore::User.find_by(email: 'admin@datacycle.at').id,
            language: ['de'],
            parameters: [{
              'n' => 'Suchbegriff',
              't' => 'fulltext_search',
              'v' => 'test'
            }]
          )

          assert_equal(@data_set.linked_creative_work.count, @linked_objects.size)
          assert_equal(@data_set.linked_creative_work(linked_filter).count, 1)
        end

        test 'replace linked with only one item' do
          linked_objects = @linked_objects
          data_set = @data_set

          count_things(diff: [0, 1, 1 - linked_objects.size, linked_objects.size]) do
            data_set.set_data_hash(
              data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
                {
                  'linked_creative_work' => [linked_objects.first]
                }
              )
            )
          end
        end

        test 'try to add linked consisting of only an empty string' do
          linked_objects = @linked_objects
          data_set = @data_set
          count_things(diff: [0, 1, -1 * linked_objects.size, linked_objects.size]) do
            data_set.set_data_hash(
              data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
                {
                  'linked_creative_work' => ['']
                }
              )
            )
          end
        end

        test 'delete main entity' do
          linked_objects = @linked_objects
          data_set = @data_set

          count_things(diff: [-1, 1, -5, 5]) do
            data_set.destroy_content
            assert_equal(linked_objects.size, DataCycleCore::Thing.count - @things_before)
          end

          count_things(diff: [0, -1, 0, -5]) do
            data_set.histories.each(&:destroy_content)
            assert_equal(linked_objects.size, DataCycleCore::Thing.count - @things_before)
          end
        end

        test 'create entity and add linked entity from same table, remove last 2 linked' do
          linked_objects = @linked_objects
          data_set = @data_set

          count_things(diff: [0, 1, -2, 5]) do
            data_set.set_data_hash(
              data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
                {
                  'linked_creative_work' => linked_objects.first(3)
                }
              )
            )
          end
        end

        test 'add another 2 linked' do
          linked_objects = @linked_objects
          data_set = @data_set
          linked_objects2 = []

          count_things(diff: [2, 1, 2, 5]) do
            2.times do |i|
              linked_objects2.push(DataCycleCore::TestPreparations.create_content(template_name: 'Linked-Creative-Work-2', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge({ 'name' => "CreativeWork Linked Additional #{i}" }), prevent_history: true).id)
            end

            data_set.set_data_hash(
              data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
                {
                  'linked_creative_work' => linked_objects + linked_objects2
                }
              ),
              partial_update: true
            )
          end
        end

        test 'change order' do
          linked_objects = @linked_objects
          data_set = @data_set

          linked_data = data_set.linked_creative_work.map(&:id)
          linked_objects.each_index do |index|
            assert_equal(linked_objects[index], linked_data[index])
          end

          count_things(diff: [0, 1, 0, 5]) do
            data_set.set_data_hash(
              data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
                {
                  'linked_creative_work' => [
                    linked_objects[4],
                    linked_objects[3],
                    linked_objects[2],
                    linked_objects[1],
                    linked_objects[0]
                  ]
                }
              )
            )
          end

          linked_data = data_set.linked_creative_work.map(&:id)
          linked_objects.each_index do |index|
            assert_equal(linked_objects[-(index + 1)], linked_data[index])
          end
        end

        test 'remove linked entities and add other linked entities' do
          linked_cw_size = @linked_objects.size
          data_set = @data_set
          place_count = 3
          linked_places = []

          count_things(diff: [3, 0, 0, 0]) do
            place_count.times do |i|
              linked_places.push(DataCycleCore::TestPreparations.create_content(template_name: 'Linked-Place-1', data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'linked').merge({ 'name' => "CreativeWork Linked Headline #{i}" }), prevent_history: true).id)
            end
            assert_equal(place_count, linked_places.size)
            assert_equal(DataCycleCore::Thing.where(template_name: 'Linked-Place-1').count, linked_places.size)
          end

          count_things(diff: [0, 1, place_count - linked_cw_size, linked_cw_size]) do
            data_set.set_data_hash(
              data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
                {
                  'linked_place' => linked_places.dup,
                  'linked_creative_work' => []
                }
              )
            )
            assert_equal(place_count, linked_places.size)
            assert_equal(DataCycleCore::Thing.where(template_name: 'Linked-Place-1').count, linked_places.size)
          end
        end

        test 'delete one linked item and check history, no content_content_history created' do
          data_set = @data_set
          count_things(diff: [-1, +1, -1, 0]) do
            assert_equal(@linked_objects.count, data_set.linked_creative_work.count)
            linked_cw = data_set.linked_creative_work.first
            linked_cw.destroy_content
          end
          assert_equal(4, data_set.linked_creative_work.count)
        end

        test 'delete main object, content_content_history created' do
          data_set = @data_set
          count_things(diff: [-1, +1, -5, +5]) do
            data_set.destroy_content
          end
        end

        test 'delete main object, check relation of history_item' do
          data_set = @data_set
          data_set.destroy_content

          history_item = data_set.histories.first
          assert_equal(5, history_item.linked_creative_work.count)
        end

        test 'delete main object, delete linked item' do
          data_set = @data_set
          count_things(diff: [-2, +2, -5, +5]) do
            linked_item = data_set.linked_creative_work.first
            data_set.destroy_content

            main_item = data_set.histories.first
            assert_equal(5, main_item.linked_creative_work.count)
            assert_equal(5, DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Thing').count)

            linked_item.destroy_content
          end
          assert_equal(1, DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Thing::History').count)
          assert_equal(4, DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Thing').count)
        end

        test 'delete main object, update linked item, delete_linked item' do
          data_set = @data_set

          count_things(diff: [-2, 3, -5, +5]) do
            linked_item = data_set.linked_creative_work.first
            data_set.destroy_content
            main_item = data_set.histories.first
            assert_equal(5, main_item.linked_creative_work.count)
            assert_equal(5, DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Thing').count)

            linked_item.set_data_hash(data_hash: linked_item.get_data_hash.merge('name' => 'updated'))
            linked_item.set_data_hash(data_hash: linked_item.get_data_hash.merge('name' => 'updated 2x'))
            linked_item.destroy_content
            assert_equal(2, linked_item.histories.count)
            assert_equal(1, linked_item.histories.where.not(deleted_at: nil).count)
            deleted_linked = linked_item.histories.where.not(deleted_at: nil).first
            assert_equal(DataCycleCore::ContentContent::History.find_by(content_b_history_type: 'DataCycleCore::Thing::History').content_b_history_id, deleted_linked.id)
          end

          assert_equal(1, DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Thing::History').count)
          assert_equal(4, DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Thing').count)
        end
      end
    end
  end
end
