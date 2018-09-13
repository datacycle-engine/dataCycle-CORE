# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class EmbeddedLinkTest < ActiveSupport::TestCase
    test 'create article and add embeddedLinks' do
      cw_temp = DataCycleCore::CreativeWork.count
      template_bild = DataCycleCore::CreativeWork.where(template: true, template_name: 'Bild').first

      image_objects = []
      (1..5).each do |number|
        image = DataCycleCore::CreativeWork.new
        image.schema = template_bild.schema
        image.template_name = template_bild.template_name
        image.save
        image.set_data_hash(data_hash: { 'headline' => "Bild#{number}", 'description' => "Description Bild#{number}" }, prevent_history: true)
        image.save
        image_objects.push(image.id)
      end

      assert_equal(image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      template = DataCycleCore::CreativeWork.where(template: true, template_name: 'Artikel').first
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test article!',
          'description' => 'Article test description!'
        },
        prevent_history: true
      )
      data_set.save
      assert_equal(1 + image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test article!',
          'description' => 'Article test description!',
          'image' => image_objects
        }
      )
      data_set.save
      assert_equal(1 + image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(5, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test article!',
          'description' => 'Article test description!',
          'image' => [image_objects.first]
        }
      )
      data_set.save
      assert_equal(1 + image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(5, DataCycleCore::ContentContent::History.count)
    end

    test 'create article and add embeddedLinks, delete_all' do
      cw_temp = DataCycleCore::CreativeWork.count

      template_bild = DataCycleCore::CreativeWork.where(template: true, template_name: 'Bild').first

      image_objects = []
      (1..5).each do |number|
        image = DataCycleCore::CreativeWork.new
        image.schema = template_bild.schema
        image.template_name = template_bild.template_name
        image.save
        image.set_data_hash(data_hash: { 'headline' => "Bild#{number}", 'description' => "Description Bild#{number}" }, prevent_history: true)
        image.save
        image_objects.push(image.id)
      end

      assert_equal(image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      template = DataCycleCore::CreativeWork.where(template: true, template_name: 'Artikel').first
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test article!',
          'description' => 'Article test description!'
        },
        prevent_history: true
      )
      data_set.save
      assert_equal(1 + image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Test article!',
          'description' => 'Article test description!',
          'image' => image_objects
        }
      )
      data_set.save
      assert_equal(1 + image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(5, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.destroy_content

      assert_equal(image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(5, DataCycleCore::ContentContent::History.count)

      data_set.histories.each(&:destroy_content)

      assert_equal(image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
    end

    test 'create creative_work and add 3 embeddedLinks, test change order' do
      cw_temp = DataCycleCore::CreativeWork.count

      main_template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'TestEmbeddedArray')
      linked_template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'TestClassificationData')

      linked_objects = []
      (1..3).each do |number|
        linked_object = DataCycleCore::CreativeWork.new
        linked_object.schema = linked_template.schema
        linked_object.template_name = linked_template.template_name
        linked_object.save
        linked_object.set_data_hash(data_hash: { 'headline' => "Eintrag: #{number}" }, prevent_history: true)
        linked_object.save
        linked_objects.push(linked_object.id)
      end

      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = main_template.schema
      data_set.template_name = main_template.template_name
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Main'
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
          'headline' => 'Main',
          'testArray' => linked_objects.dup
        }
      )
      data_set.save
      assert_equal(1 + linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      linked_data = data_set.testArray.map(&:id)
      linked_objects.each_index do |index|
        assert_equal(linked_objects[index], linked_data[index])
      end

      # set data_links in reversed_order
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Main',
          'testArray' => [
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

      linked_data = data_set.testArray.map(&:id)
      linked_objects.each_index do |index|
        assert_equal(linked_objects[-(index + 1)], linked_data[index])
      end
    end

    test 'create place and add 3 embeddedLinks, test change order' do
      cw_temp = DataCycleCore::CreativeWork.count
      place_temp = DataCycleCore::Place.count

      main_template = DataCycleCore::Place.find_by(template: true, template_name: 'testPlaceLink')
      linked_template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'TestClassificationData')

      linked_objects = []
      (1..3).each do |number|
        linked_object = DataCycleCore::CreativeWork.new
        linked_object.schema = linked_template.schema
        linked_object.template_name = linked_template.template_name
        linked_object.save
        linked_object.set_data_hash(data_hash: { 'headline' => "Eintrag: #{number}" }, prevent_history: true)
        linked_object.save
        linked_objects.push(linked_object.id)
      end

      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::Place.count - place_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::Place::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set = DataCycleCore::Place.new
      data_set.schema = main_template.schema
      data_set.template_name = main_template.template_name
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Main'
        },
        prevent_history: true
      )
      data_set.save
      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(1, DataCycleCore::Place.count - place_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::Place::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Main',
          'testArray' => linked_objects.dup
        }
      )
      data_set.save
      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(1, DataCycleCore::Place.count - place_temp)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::Place::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      linked_data = data_set.testArray.map(&:id)
      linked_objects.each_index do |index|
        assert_equal(linked_objects[index], linked_data[index])
      end

      # set data_links in reversed_order
      data_set.set_data_hash(
        data_hash: {
          'headline' => 'Main',
          'testArray' => [
            linked_objects[2],
            linked_objects[1],
            linked_objects[0]
          ]
        }
      )
      data_set.save

      assert_equal(linked_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(1, DataCycleCore::Place.count - place_temp)
      assert_equal(3, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(2, DataCycleCore::Place::History.count)
      assert_equal(3, DataCycleCore::ContentContent::History.count)

      linked_data = data_set.testArray.map(&:id)
      linked_objects.each_index do |index|
        assert_equal(linked_objects[-(index + 1)], linked_data[index])
      end
    end
  end
end
