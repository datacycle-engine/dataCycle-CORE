# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class LinkedTest < ActiveSupport::TestCase
        def setup
          # create entity and add 5linked entities from the same table
          @cw_temp = DataCycleCore::CreativeWork.count

          @linked_objects = []
          5.times do
            linked = DataCycleCore::TestPreparations.data_set_object('creative_works', 'Linked-Creative-Work-2')
            linked.save
            linked.set_data_hash(data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked'), prevent_history: true)
            linked.save
            @linked_objects.push(linked.id)
          end

          assert_equal(@linked_objects.size, DataCycleCore::CreativeWork.count - @cw_temp)
          assert_equal(@linked_objects.size, DataCycleCore::CreativeWork.count - @cw_temp)
          assert_equal(0, DataCycleCore::ContentContent.count)
          assert_equal(0, DataCycleCore::CreativeWork::History.count)
          assert_equal(0, DataCycleCore::ContentContent::History.count)

          @data_set = DataCycleCore::TestPreparations.data_set_object('creative_works', 'Linked-Creative-Work-1')
          @data_set.save
          @data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked'),
            prevent_history: true
          )
          @data_set.save

          assert_equal(1 + @linked_objects.size, DataCycleCore::CreativeWork.count - @cw_temp)
          assert_equal(0, DataCycleCore::ContentContent.count)
          assert_equal(0, DataCycleCore::CreativeWork::History.count)
          assert_equal(0, DataCycleCore::ContentContent::History.count)

          @data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
              {
                'linked_creative_work' => @linked_objects
              }
            )
          )
          @data_set.save
          assert_equal(1 + @linked_objects.size, DataCycleCore::CreativeWork.count - @cw_temp)
          assert_equal(5, DataCycleCore::ContentContent.count)
          assert_equal(1, DataCycleCore::CreativeWork::History.count)
          assert_equal(0, DataCycleCore::ContentContent::History.count)
        end

        test 'override linked with only one item' do
          linked_objects = @linked_objects
          data_set = @data_set

          data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
              {
                'linked_creative_work' => [linked_objects.first]
              }
            )
          )
          data_set.save

          assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - @cw_temp)
          assert_equal(1, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::CreativeWork::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)
        end

        test 'create entity and add linked entity from same table, delete main entity' do
          linked_objects = @linked_objects
          data_set = @data_set

          data_set.destroy_content

          assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - @cw_temp)
          assert_equal(0, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::CreativeWork::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)

          data_set.histories.each(&:destroy_content)

          assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - @cw_temp)
          assert_equal(0, DataCycleCore::ContentContent.count)
          assert_equal(0, DataCycleCore::CreativeWork::History.count)
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
          data_set.save
          assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - @cw_temp)
          assert_equal(3, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::CreativeWork::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)
        end

        test 'create entity and add linked entity from same table, save, add another 2 linked' do
          linked_objects = @linked_objects
          data_set = @data_set

          linked_objects2 = []
          2.times do
            linked = DataCycleCore::TestPreparations.data_set_object('creative_works', 'Linked-Creative-Work-2')
            linked.save
            linked.set_data_hash(data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked'), prevent_history: true)
            linked.save
            linked_objects2.push(linked.id)
          end

          data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
              {
                'linked_creative_work' => linked_objects + linked_objects2
              }
            )
          )
          data_set.save
          assert_equal(1 + linked_objects.size + linked_objects2.size, DataCycleCore::CreativeWork.count - @cw_temp)
          assert_equal(7, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::CreativeWork::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)
        end

        test 'create entity and add 5 linked entities, test change order' do
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
          data_set.save

          assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - @cw_temp)
          assert_equal(5, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::CreativeWork::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)

          linked_data = data_set.linked_creative_work.map(&:id)
          linked_objects.each_index do |index|
            assert_equal(linked_objects[-(index + 1)], linked_data[index])
          end
        end

        test 'create entity and add linked entity from other table' do
          data_set = @data_set

          place_temp = DataCycleCore::Place.count

          linked_places = []
          3.times do
            place = DataCycleCore::TestPreparations.data_set_object('places', 'Linked-Place-1')
            place.save
            place.set_data_hash(data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('places', 'linked'), prevent_history: true)
            place.save
            linked_places.push(place.id)
          end

          assert_equal(linked_places.size, DataCycleCore::Place.count - place_temp)
          assert_equal(5, DataCycleCore::ContentContent.count)
          assert_equal(0, DataCycleCore::Place::History.count)

          data_set.set_data_hash(
            data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge(
              {
                'linked_place' => linked_places.dup
              }
            )
          )
          data_set.save
          assert_equal(linked_places.size, DataCycleCore::Place.count - place_temp)
          assert_equal(6, DataCycleCore::CreativeWork.count - @cw_temp)
          assert_equal(3, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::CreativeWork::History.count)
          assert_equal(0, DataCycleCore::Place::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)
        end
      end
    end
  end
end
