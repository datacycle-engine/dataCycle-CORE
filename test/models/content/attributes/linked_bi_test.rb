# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class LinkedBiTest < ActiveSupport::TestCase
        include DataCycleCore::DataHelper

        def setup
          # create entity and add 5 linked entities from the same table
          @things_before = DataCycleCore::Thing.count
          linked_size = 5
          @linked_objects = []

          count_things(diff: [linked_size, 0, 0, 0]) do
            (1..linked_size).each do |i|
              @linked_objects.push(DataCycleCore::TestPreparations.create_content(template_name: 'Place-Bi', data_hash: place_hash(i), prevent_history: true).id)
            end
          end

          count_things(diff: [1, 0, 0, 0]) do
            @data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Tour-Bi', data_hash: tour_hash, prevent_history: true)
          end

          count_things(diff: [0, 0, 5, 0]) do
            @data_set.set_data_hash(data_hash: tour_hash.merge({ 'linked_place' => @linked_objects }))
            @data_set.save
          end
        end

        def tour_hash
          { 'name' => 'Tour-Bi', 'description' => 'Tour-Bi-description' }
        end

        def place_hash(i)
          { 'name' => "Place-Bi-#{i}", 'description' => "Place-Bi-description-#{i}" }
        end

        def content_content_hash(id)
          {
            content_a_id: id,
            relation_a: 'linked_place',
            relation_b: 'linked_tour'
          }
        end

        def content_content_history_hash(id)
          {
            content_a_history_id: id,
            relation_a: 'linked_place',
            relation_b: 'linked_tour',
            content_b_history_type: 'DataCycleCore::Thing'
          }
        end

        test 'replace linked with only one item' do
          linked_objects = @linked_objects
          data_set = @data_set

          count_things(diff: [0, 1, 1 - linked_objects.size, linked_objects.size]) do
            data_set.set_data_hash(data_hash: tour_hash.merge({ 'linked_place' => [linked_objects.first] }))
          end

          assert_equal(1, data_set.linked_place.count)
          assert_equal(1, data_set.linked_place.first.linked_tour.count)
        end

        test 'remove last 2 linked' do
          linked_objects = @linked_objects
          data_set = @data_set

          count_things(diff: [0, 1, -2, 5]) do
            data_set.set_data_hash(data_hash: tour_hash.merge({ 'linked_place' => linked_objects.first(3) }))
          end

          assert_equal(3, data_set.linked_place.count)
          assert_equal(3, DataCycleCore::ContentContent.where(content_content_hash(data_set.id)).count)
        end

        test 'append 2 new linked items' do
          linked_objects = @linked_objects
          data_set = @data_set
          linked_objects2 = []

          count_things(diff: [2, 1, 2, 5]) do
            (1..2).each do |i|
              linked_objects2.push(DataCycleCore::TestPreparations.create_content(template_name: 'Place-Bi', data_hash: place_hash(i * 100), prevent_history: true).id)
            end

            data_set.set_data_hash(data_hash: tour_hash.merge({ 'linked_place' => linked_objects + linked_objects2 }))
          end

          assert_equal(7, data_set.linked_place.count)
          assert_equal(5, data_set.histories.first.linked_place.count)
          assert_equal(7, DataCycleCore::ContentContent.where(content_content_hash(data_set.id)).count)
          assert_equal(5, DataCycleCore::ContentContent::History.where(content_content_history_hash(data_set.histories.first.id)).count)
        end

        test 'delete one linked item and check history, no content_content_history created' do
          data_set = @data_set
          linked_place = data_set.linked_place.first

          count_things(diff: [-1, +1, -1, 0]) do
            assert_equal(@linked_objects.count, data_set.linked_place.count)
            linked_place.destroy_content
          end

          assert_equal(4, data_set.linked_place.count)
          assert_equal(0, linked_place.linked_tour.count)
          assert_equal(0, linked_place.histories.first.linked_tour.count)
        end

        test 'delete main object, content_content_history created' do
          data_set = @data_set
          linked_place = data_set.linked_place.first
          assert_equal(1, linked_place.linked_tour.count)

          count_things(diff: [-1, +1, -5, +5]) do
            data_set.destroy_content
          end

          assert_equal(5, data_set.histories.first.linked_place.count)
          assert_equal(0, linked_place.linked_tour.count)
        end

        test 'delete main object, update linked item, delete_linked item' do
          data_set = @data_set

          count_things(diff: [-2, 3, -5, +5]) do
            linked_item = data_set.linked_place.first
            data_set.destroy_content
            main_item = data_set.histories.first

            assert_equal(5, main_item.linked_place.count)
            assert_equal(5, DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Thing').count)
            assert_equal(0, linked_item.linked_tour.count)

            linked_item.set_data_hash(data_hash: linked_item.get_data_hash.merge('name' => 'updated'))
            linked_item.set_data_hash(data_hash: linked_item.get_data_hash.merge('name' => 'updated 2x'))
            linked_item.destroy_content

            deleted_items = linked_item.histories.where.not(deleted_at: nil)
            deleted_linked = deleted_items.first
            assert_equal(2, linked_item.histories.count)
            assert_equal(1, deleted_items.count)
            assert_equal(1, deleted_linked.linked_tour.count)
            assert_equal(DataCycleCore::ContentContent::History.find_by(content_b_history_type: 'DataCycleCore::Thing::History').content_b_history_id, deleted_linked.id)
          end

          assert_equal(1, DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Thing::History').count)
          assert_equal(4, DataCycleCore::ContentContent::History.where(content_b_history_type: 'DataCycleCore::Thing').count)
        end
      end
    end
  end
end
