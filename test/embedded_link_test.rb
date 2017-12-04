require 'test_helper'

module DataCycleCore
  class EmbeddedLinkTest < ActiveSupport::TestCase

    test "create article and add embeddedLinks" do
      cw_temp = DataCycleCore::CreativeWork.count

      template_bild = DataCycleCore::CreativeWork.where(template: true, headline: "Bild", description: "ImageObject").first
      validation_bild = template_bild.metadata['validation']

      image_objects = []
      (1..5).each do |number|
        image = DataCycleCore::CreativeWork.new
        image.metadata = { 'validation' => validation_bild }
        image.save
        image.set_data_hash(data_hash: {"headline" => "Bild#{number}", "description" => "Description Bild#{number}"}, prevent_history: true)
        image.save
        image_objects.push(image.id)
      end

      assert_equal(image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      template = DataCycleCore::CreativeWork.where(template: true, headline: "Artikel", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          "headline" => "Test article!",
          "description" => "Article test description!"
        },
        prevent_history: true
      )
      data_set.save
      assert_equal(1+image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          "headline" => "Test article!",
          "description" => "Article test description!",
          "image" => image_objects
        }
      )
      data_set.save
      assert_equal(1+image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(5, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          "headline" => "Test article!",
          "description" => "Article test description!",
          "image" => [image_objects.first]
        }
      )
      data_set.save
      assert_equal(1+image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(5, DataCycleCore::ContentContent::History.count)
    end

    test "create article and add embeddedLinks, delete_all" do
      cw_temp = DataCycleCore::CreativeWork.count

      template_bild = DataCycleCore::CreativeWork.where(template: true, headline: "Bild", description: "ImageObject").first
      validation_bild = template_bild.metadata['validation']

      image_objects = []
      (1..5).each do |number|
        image = DataCycleCore::CreativeWork.new
        image.metadata = { 'validation' => validation_bild }
        image.save
        image.set_data_hash(data_hash: {"headline" => "Bild#{number}", "description" => "Description Bild#{number}"}, prevent_history: true)
        image.save
        image_objects.push(image.id)
      end

      assert_equal(image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      template = DataCycleCore::CreativeWork.where(template: true, headline: "Artikel", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_set.set_data_hash(
        data_hash: {
          "headline" => "Test article!",
          "description" => "Article test description!"
        },
        prevent_history: true
      )
      data_set.save
      assert_equal(1+image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(
        data_hash: {
          "headline" => "Test article!",
          "description" => "Article test description!",
          "image" => image_objects
        }
      )
      data_set.save
      assert_equal(1+image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(5, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)


      data_set.destroy_content
      data_set.destroy

      assert_equal(image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(5, DataCycleCore::ContentContent::History.count)

      data_set.histories.each do |item|
        item.destroy_content
        item.destroy
      end

      assert_equal(image_objects.size, DataCycleCore::CreativeWork.count - cw_temp)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
    end

  end
end
