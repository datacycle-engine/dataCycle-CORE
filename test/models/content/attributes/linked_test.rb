# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class LinkedTest < ActiveSupport::TestCase
        def setup
          # create entity and add 5 linked entities from the same table
          @things_before = DataCycleCore::Thing.count

          @linked_objects = []
          5.times do
            linked = DataCycleCore::TestPreparations.data_set_object('Linked-Creative-Work-2')
            linked.save
            linked.set_data_hash(data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked'), prevent_history: true)
            linked.save
            @linked_objects.push(linked.id)
          end

          assert_equal(@linked_objects.size, DataCycleCore::Thing.count - @things_before)
          assert_equal(0, DataCycleCore::ContentContent.count)
          assert_equal(0, DataCycleCore::Thing::History.count)
          assert_equal(0, DataCycleCore::ContentContent::History.count)

          @data_set = DataCycleCore::TestPreparations.data_set_object('Linked-Creative-Work-1')
          @data_set.save
          @data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked'),
            prevent_history: true
          )
          @data_set.save

          assert_equal(1 + @linked_objects.size, DataCycleCore::Thing.count - @things_before)
          assert_equal(0, DataCycleCore::ContentContent.count)
          assert_equal(0, DataCycleCore::Thing::History.count)
          assert_equal(0, DataCycleCore::ContentContent::History.count)

          @data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
              {
                'linked_creative_work' => @linked_objects
              }
            )
          )
          @data_set.save
          assert_equal(1 + @linked_objects.size, DataCycleCore::Thing.count - @things_before)
          assert_equal(5, DataCycleCore::ContentContent.count)
          assert_equal(1, DataCycleCore::Thing::History.count)
          assert_equal(0, DataCycleCore::ContentContent::History.count)
        end

        test 'replace linked with only one item' do
          linked_objects = @linked_objects
          data_set = @data_set
          data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
              {
                'linked_creative_work' => [linked_objects.first]
              }
            )
          )
          assert_equal(1 + linked_objects.size, DataCycleCore::Thing.count - @things_before)
          assert_equal(1, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::Thing::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)
        end

        test 'delete main entity' do
          linked_objects = @linked_objects
          data_set = @data_set

          data_set.destroy_content

          assert_equal(linked_objects.size, DataCycleCore::Thing.count - @things_before)
          assert_equal(0, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::Thing::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)

          data_set.histories.each(&:destroy_content)

          assert_equal(linked_objects.size, DataCycleCore::Thing.count - @things_before)
          assert_equal(0, DataCycleCore::ContentContent.count)
          assert_equal(0, DataCycleCore::Thing::History.count)
          assert_equal(0, DataCycleCore::ContentContent::History.count)
        end

        test 'create entity and add linked entity from same table, remove last 2 linked' do
          linked_objects = @linked_objects
          data_set = @data_set

          data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
              {
                'linked_creative_work' => linked_objects.first(3)
              }
            )
          )
          assert_equal(1 + linked_objects.size, DataCycleCore::Thing.count - @things_before)
          assert_equal(3, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::Thing::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)
        end

        test 'add another 2 linked' do
          linked_objects = @linked_objects
          data_set = @data_set

          linked_objects2 = []
          2.times do
            linked = DataCycleCore::TestPreparations.data_set_object('Linked-Creative-Work-2')
            linked.save
            linked.set_data_hash(data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked'), prevent_history: true)
            linked_objects2.push(linked.id)
          end

          data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
              {
                'linked_creative_work' => linked_objects + linked_objects2
              }
            )
          )
          assert_equal(1 + linked_objects.size + linked_objects2.size, DataCycleCore::Thing.count - @things_before)
          assert_equal(7, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::Thing::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)
        end

        test 'change order' do
          linked_objects = @linked_objects
          data_set = @data_set

          linked_data = data_set.linked_creative_work.map(&:id)
          linked_objects.each_index do |index|
            assert_equal(linked_objects[index], linked_data[index])
          end

          # set data_links in reversed_order
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
          assert_equal(1 + linked_objects.size, DataCycleCore::Thing.count - @things_before)
          assert_equal(5, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::Thing::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)

          linked_data = data_set.linked_creative_work.map(&:id)
          linked_objects.each_index do |index|
            assert_equal(linked_objects[-(index + 1)], linked_data[index])
          end
        end

        test 'remove linked entities and add other linked entities' do
          data_set = @data_set
          setup_history = 1
          place_count = 3

          linked_places = []
          place_count.times do
            place = DataCycleCore::TestPreparations.data_set_object('Linked-Place-1')
            place.save
            place.set_data_hash(data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'linked'), prevent_history: true)
            linked_places.push(place.id)
          end

          assert_equal(linked_places.size, place_count)
          assert_equal(linked_places.size, DataCycleCore::Thing.where(template: false, template_name: 'Linked-Place-1').count)
          assert_equal(5, DataCycleCore::ContentContent.count)
          assert_equal(0, DataCycleCore::Thing::History.count - setup_history)
          assert_equal(0, DataCycleCore::ContentContent::History.count)

          data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
              {
                'linked_place' => linked_places.dup
              }
            )
          )
          assert_equal(linked_places.size, place_count)
          assert_equal(linked_places.size, DataCycleCore::Thing.where(template: false, template_name: 'Linked-Place-1').count)
          assert_equal(@linked_objects.count + place_count + 1, DataCycleCore::Thing.count - @things_before)
          assert_equal(3, DataCycleCore::ContentContent.count)
          assert_equal(1, DataCycleCore::Thing::History.count - setup_history)
          assert_equal(5, DataCycleCore::ContentContent::History.count)
        end

        test 'delete one linked item and check history, no content_content_history created' do
          data_set = @data_set
          before = {
            thing: DataCycleCore::Thing.count,
            thing_history: DataCycleCore::Thing::History.count,
            content_content: DataCycleCore::ContentContent.count,
            content_content_history: DataCycleCore::ContentContent::History.count
          }

          assert_equal(@linked_objects.count, data_set.linked_creative_work.count)

          linked_cw = data_set.linked_creative_work.first
          linked_cw.destroy_content

          assert_equal(4, data_set.linked_creative_work.count)
          assert_equal(before[:thing] - 1, DataCycleCore::Thing.count)
          assert_equal(before[:content_content] - 1, DataCycleCore::ContentContent.count)
          assert_equal(before[:thing_history] + 1, DataCycleCore::Thing::History.count)
          assert_equal(before[:content_content_history], DataCycleCore::ContentContent::History.count)
        end

        test 'delete main object, content_content_history created' do
          data_set = @data_set
          before = {
            thing: DataCycleCore::Thing.count,
            thing_history: DataCycleCore::Thing::History.count,
            content_content: DataCycleCore::ContentContent.count,
            content_content_history: DataCycleCore::ContentContent::History.count
          }

          data_set.destroy_content

          assert_equal(before[:thing] - 1, DataCycleCore::Thing.count)
          assert_equal(before[:content_content] - 5, DataCycleCore::ContentContent.count)
          assert_equal(before[:thing_history] + 1, DataCycleCore::Thing::History.count)
          assert_equal(before[:content_content_history] + 5, DataCycleCore::ContentContent::History.count)
        end

        test 'delete main object, check relation of history_item' do
          data_set = @data_set
          data_set.destroy_content

          history_item = data_set.histories.first
          assert_equal(5, history_item.linked_creative_work.count)
        end

        test 'delete main object, delete linked item' do
          data_set = @data_set
          before = data_counts

          linked_item = data_set.linked_creative_work.first
          data_set.destroy_content

          main_item = data_set.histories.first
          assert_equal(5, main_item.linked_creative_work.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)

          linked_item.destroy_content
          linked_history = linked_item.histories.first
          after_main_destroy = data_counts
          assert_data(before, after_main_destroy, [-2, +2, -5, +5])
          linked_history.destroy_content
          after_linked_destroy = data_counts
          assert_data(after_main_destroy, after_linked_destroy, [-1, +1, 0, -1]) # ContentContent::History disappears because referenced Thing does not exist any more
        end

        def data_counts
          [
            DataCycleCore::Thing.count,
            DataCycleCore::Thing::History.count,
            DataCycleCore::ContentContent.count,
            DataCycleCore::ContentContent::History.count
          ]
        end

        def assert_data(before, after, diff)
          before.zip(after.zip(diff)).map(&:flatten).each do |item|
            assert(item[0] - item [1], item[2])
          end
        end
      end
    end
  end
end
