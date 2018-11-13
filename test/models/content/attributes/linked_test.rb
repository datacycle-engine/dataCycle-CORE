# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class LinkedTest < ActiveSupport::TestCase
        def setup
          # create entity and add 5 linked entities from the same table
          @cw_temp = DataCycleCore::Thing.count

          @linked_objects = []
          5.times do
            linked = DataCycleCore::TestPreparations.data_set_object('Linked-Creative-Work-2')
            linked.save
            linked.set_data_hash(data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked'), prevent_history: true)
            linked.save
            @linked_objects.push(linked.id)
          end

          assert_equal(@linked_objects.size, DataCycleCore::Thing.count - @cw_temp)
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

          assert_equal(1 + @linked_objects.size, DataCycleCore::Thing.count - @cw_temp)
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
          assert_equal(1 + @linked_objects.size, DataCycleCore::Thing.count - @cw_temp)
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
          assert_equal(1 + linked_objects.size, DataCycleCore::Thing.count - @cw_temp)
          assert_equal(1, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::Thing::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)
        end

        test 'delete main entity' do
          linked_objects = @linked_objects
          data_set = @data_set

          data_set.destroy_content

          assert_equal(linked_objects.size, DataCycleCore::Thing.count - @cw_temp)
          assert_equal(0, DataCycleCore::ContentContent.count)
          assert_equal(2, DataCycleCore::Thing::History.count)
          assert_equal(5, DataCycleCore::ContentContent::History.count)

          data_set.histories.each(&:destroy_content)

          assert_equal(linked_objects.size, DataCycleCore::Thing.count - @cw_temp)
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
          assert_equal(1 + linked_objects.size, DataCycleCore::Thing.count - @cw_temp)
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
          assert_equal(1 + linked_objects.size + linked_objects2.size, DataCycleCore::Thing.count - @cw_temp)
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
          assert_equal(1 + linked_objects.size, DataCycleCore::Thing.count - @cw_temp)
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
          assert_equal(@linked_objects.count + place_count + 1, DataCycleCore::Thing.count - @cw_temp)
          assert_equal(3, DataCycleCore::ContentContent.count)
          assert_equal(1, DataCycleCore::Thing::History.count - setup_history)
          assert_equal(5, DataCycleCore::ContentContent::History.count)
        end
      end
    end
  end
end
