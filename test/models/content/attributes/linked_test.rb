# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class LinkedTest < ActiveSupport::TestCase
    test 'create entity and add linked entity from same table' do
      cw_temp = DataCycleCore::CreativeWork.count

      template_main = DataCycleCore::CreativeWork.where(template: true, template_name: 'Linked-Creative-Work-1').first
      template_linked = DataCycleCore::CreativeWork.where(template: true, template_name: 'Linked-Creative-Work-2').first

      linked_objects = []
      (1..5).each do |number|
        linked = DataCycleCore::CreativeWork.new
        linked.schema = template_linked.schema
        linked.template_name = template_linked.template_name
        linked.save
        linked.set_data_hash(data_hash: { 'headline' => "Linked#{number}", 'description' => "Description Linked#{number}" }, prevent_history: true)
        linked.save
        linked_objects.push(linked.id)
      end

      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template_main.schema
      data_set.template_name = template_main.template_name
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!'
        },
        prevent_history: true
      )
      data_set.save

      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!',
          'linked_creative_work' => linked_objects
        }
      )
      data_set.save
      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(5, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!',
          'linked_creative_work' => [linked_objects.first]
        }
      )
      data_set.save
      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(5, DataCycleCore::ContentContent::History.count)
    end

    test 'create entity and add linked entity from same table, delete main entity' do
      cw_temp = DataCycleCore::CreativeWork.count

      template_main = DataCycleCore::CreativeWork.where(template: true, template_name: 'Linked-Creative-Work-1').first
      template_linked = DataCycleCore::CreativeWork.where(template: true, template_name: 'Linked-Creative-Work-2').first

      linked_objects = []
      (1..5).each do |number|
        linked = DataCycleCore::CreativeWork.new
        linked.schema = template_linked.schema
        linked.template_name = template_linked.template_name
        linked.save
        linked.set_data_hash(data_hash: { 'headline' => "Linked#{number}", 'description' => "Description Linked#{number}" }, prevent_history: true)
        linked.save
        linked_objects.push(linked.id)
      end

      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template_main.schema
      data_set.template_name = template_main.template_name
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!'
        },
        prevent_history: true
      )
      data_set.save
      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!',
          'linked_creative_work' => linked_objects
        }
      )
      data_set.save
      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(5, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.destroy_content

      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(5, DataCycleCore::ContentContent::History.count)

      data_set.histories.each(&:destroy_content)

      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
    end

    test 'create entity and add linked entity from same table, remove last 2 linked' do
      cw_temp = DataCycleCore::CreativeWork.count

      template_main = DataCycleCore::CreativeWork.where(template: true, template_name: 'Linked-Creative-Work-1').first
      template_linked = DataCycleCore::CreativeWork.where(template: true, template_name: 'Linked-Creative-Work-2').first

      linked_objects = []
      (1..5).each do |number|
        linked = DataCycleCore::CreativeWork.new
        linked.schema = template_linked.schema
        linked.template_name = template_linked.template_name
        linked.save
        linked.set_data_hash(data_hash: { 'headline' => "Linked#{number}", 'description' => "Description Linked#{number}" }, prevent_history: true)
        linked.save
        linked_objects.push(linked.id)
      end

      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template_main.schema
      data_set.template_name = template_main.template_name
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!'
        },
        prevent_history: true
      )
      data_set.save
      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!',
          'linked_creative_work' => linked_objects
        }
      )
      data_set.save
      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(5, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!',
          'linked_creative_work' => linked_objects.first(3)
        }
      )
      data_set.save
      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(5, DataCycleCore::ContentContent::History.count)
    end

    test 'create entity and add linked entity from same table, save, add another 2 linked' do
      cw_temp = DataCycleCore::CreativeWork.count

      template_main = DataCycleCore::CreativeWork.where(template: true, template_name: 'Linked-Creative-Work-1').first
      template_linked = DataCycleCore::CreativeWork.where(template: true, template_name: 'Linked-Creative-Work-2').first

      linked_objects = []
      (1..5).each do |number|
        linked = DataCycleCore::CreativeWork.new
        linked.schema = template_linked.schema
        linked.template_name = template_linked.template_name
        linked.save
        linked.set_data_hash(data_hash: { 'headline' => "Linked#{number}", 'description' => "Description Linked#{number}" }, prevent_history: true)
        linked.save
        linked_objects.push(linked.id)
      end

      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template_main.schema
      data_set.template_name = template_main.template_name
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!'
        },
        prevent_history: true
      )
      data_set.save
      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!',
          'linked_creative_work' => linked_objects
        }
      )
      data_set.save
      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(5, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      linked_objects2 = []
      (1..2).each do |number|
        linked = DataCycleCore::CreativeWork.new
        linked.schema = template_linked.schema
        linked.template_name = template_linked.template_name
        linked.save
        linked.set_data_hash(data_hash: { 'headline' => "Linked#{number + 5}", 'description' => "Description Linked#{number + 5}" }, prevent_history: true)
        linked.save
        linked_objects2.push(linked.id)
      end

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!',
          'linked_creative_work' => linked_objects + linked_objects2
        }
      )
      data_set.save
      assert_equal(1 + linked_objects.size + linked_objects2.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(7, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(5, DataCycleCore::ContentContent::History.count)
    end

    test 'create entity and add 3 linked entities, test change order' do
      cw_temp = DataCycleCore::CreativeWork.count

      template_main = DataCycleCore::CreativeWork.where(template: true, template_name: 'Linked-Creative-Work-1').first
      template_linked = DataCycleCore::CreativeWork.where(template: true, template_name: 'Linked-Creative-Work-2').first

      linked_objects = []
      (1..3).each do |number|
        linked_object = DataCycleCore::CreativeWork.new
        linked_object.schema = template_linked.schema
        linked_object.template_name = template_linked.template_name
        linked_object.save
        linked_object.set_data_hash(data_hash: { 'headline' => "Linked#{number}", 'description' => "Description Linked#{number}" }, prevent_history: true)
        linked_object.save
        linked_objects.push(linked_object.id)
      end

      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template_main.schema
      data_set.template_name = template_main.template_name
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!'
        },
        prevent_history: true
      )
      data_set.save
      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!',
          'linked_creative_work' => linked_objects.dup
        }
      )
      data_set.save

      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      linked_data = data_set.linked_creative_work.map(&:id)
      linked_objects.each_index do |index|
        assert_equal(linked_objects[index], linked_data[index])
      end

      # set data_links in reversed_order
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!',
          'linked_creative_work' => [
            linked_objects[2],
            linked_objects[1],
            linked_objects[0]
          ]
        }
      )
      data_set.save

      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(3, DataCycleCore::ContentContent::History.count)

      linked_data = data_set.linked_creative_work.map(&:id)
      linked_objects.each_index do |index|
        assert_equal(linked_objects[-(index + 1)], linked_data[index])
      end
    end

    test 'create entity and add linked entity from other table' do
      cw_temp = DataCycleCore::CreativeWork.count
      place_temp = DataCycleCore::Place.count

      template_main = DataCycleCore::CreativeWork.where(template: true, template_name: 'Linked-Creative-Work-1').first
      template_linked = DataCycleCore::Place.where(template: true, template_name: 'Linked-Place-1').first

      linked_objects = []
      (1..3).each do |number|
        linked_object = DataCycleCore::Place.new
        linked_object.schema = template_linked.schema
        linked_object.template_name = template_linked.template_name
        linked_object.save
        linked_object.set_data_hash(data_hash: { 'headline' => "Linked#{number}", 'description' => "Description Linked#{number}" }, prevent_history: true)
        linked_object.save
        linked_objects.push(linked_object.id)
      end

      assert_equal(linked_objects.size, DataCycleCore::Place.count - place_temp)
      assert_equal(0, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::Place::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template_main.schema
      data_set.template_name = template_main.template_name
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!'
        },
        prevent_history: true
      )
      data_set.save
      assert_equal(linked_objects.size, DataCycleCore::Place.count - place_temp)
      assert_equal(1, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::Place::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test headline!',
          'description' => 'Test description!',
          'linked_place' => linked_objects.dup
        }
      )
      data_set.save
      assert_equal(linked_objects.size, DataCycleCore::Place.count - place_temp)
      assert_equal(1, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::Place::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
    end
  end
end
