require 'test_helper'

module DataCycleCore
  class CreativeWorkHistoryTest < ActiveSupport::TestCase

    test "CreativeWork and History exists" do
      data = DataCycleCore::CreativeWork.new
      assert_equal(data.class, DataCycleCore::CreativeWork)
      data = DataCycleCore::CreativeWork::History.new
      assert_equal(data.class, DataCycleCore::CreativeWork::History)
    end

    test "create CreativeWork and store History" do

      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestSimple", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.save
      data_hash = { "headline" => "Dies ist ein Test!" }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.compact)
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)

      save_time = Time.zone.now

      # save to History table
      data_set_history = DataCycleCore::CreativeWork::History.new
      data_set_history.creative_work_id = data_set.id
      data_set.attributes.except("id").each do |key,value|
        data_set_history.send("#{key}=", value)
      end
      data_set_history.history_valid = (data_set.updated_at .. save_time)
      data_set_history.save

      assert_equal(data_set.get_data_hash, data_set_history.get_data_hash)

      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)
    end

    test "save data to History with included Object data in translated jsonb field" do

      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestIncludedData", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.save
      data_hash = { "headline" => "Dies ist ein Test!", "includedData" => { "item1" => "Test item 1", "item2" => "Test item 2"} }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.compact)
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)

#####################################################################################
      # save to History table
      save_time = Time.zone.now
      data_set_history = DataCycleCore::CreativeWork::History.new
      data_set_history.creative_work_id = data_set.id
      data_set.attributes.except("id").each do |key,value|
        data_set_history.send("#{key}=", value)
      end
      data_set_history.history_valid = (data_set.updated_at .. save_time)
      data_set_history.save
######################################################################################


      assert_equal(data_set.get_data_hash, data_set_history.get_data_hash)

      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)
    end

    test "save data to History with classification" do

      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestClassificationData", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.save
      data_hash = { "headline" => "Dies ist ein Test!"}
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.except('data_pool').compact)
      assert_equal(1, returned_data_hash['data_pool'].count)
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::ClassificationCreativeWork.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationCreativeWork::History.count)

######################################################################################
      # save to History table(s) / with classification_relations
      save_time = Time.zone.now
      data_set_history = DataCycleCore::CreativeWork::History.new
      ActiveRecord::Base.transaction do
        data_set_history.creative_work_id = data_set.id
        data_set.attributes.except("id").each do |key,value|
          data_set_history.send("#{key}=", value)
        end
        data_set_history.history_valid = (data_set.updated_at .. save_time)
        data_set_history.save

        data_set.classification_creative_works.each do |item|
          data_set_classification_history = DataCycleCore::ClassificationCreativeWork::History.new
          data_set_classification_history.creative_work_history_id = data_set_history.id
          data_set_history_valid = (item.updated_at .. save_time)
          item.attributes.except("id","creative_work_id").each do |key,value|
            data_set_classification_history.send("#{key}=", value)
          end
          data_set_classification_history.classification_id = item.classification_id
          data_set_classification_history.save
        end
      end
######################################################################################


      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::ClassificationCreativeWork.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(1, DataCycleCore::ClassificationCreativeWork::History.count)

      assert_equal(data_set.get_data_hash, data_set_history.get_data_hash)
    end

    test "save data to History with embeddedObject from another content_table" do

      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count
      template_place_count = DataCycleCore::Place.count
      template_place_t_count = DataCycleCore::Place::Translation.count

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestEmbeddedPlaceData", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.save

      template_place = DataCycleCore::Place.find_by(template: true, headline: "testPlace", description: "Place")
      validation_place_hash = template_place.metadata['validation']
      data_set_place = DataCycleCore::Place.new
      data_set_place.metadata = { 'validation' => validation_place_hash }
      data_set_place.save
      data_set_place.set_data_hash({"name" => "Das it ein testPlace!"})
      data_set_place.save

      data_hash = { "headline" => "Dies ist ein Test!", "testPlace" => [{"id" => data_set_place.id}]}
      error = data_set.set_data_hash(data_hash)
      data_set.save

      returned_data_hash = data_set.get_data_hash
      expected_hash = data_hash
      expected_hash['testPlace'][0] = data_set_place.get_data_hash
      assert_equal(data_hash, returned_data_hash)
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::Place.count - template_place_count)
      assert_equal(1, DataCycleCore::Place::Translation.count - template_place_t_count)
      assert_equal(1, DataCycleCore::CreativeWorkPlace.count)
      assert_equal(0, DataCycleCore::CreativeWorkPlace::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(0, DataCycleCore::Place::History.count)
      assert_equal(0, DataCycleCore::Place::History::Translation.count)

######################################################################################
      # save to History table(s) / with classification_relations
      save_time = Time.zone.now
      origin_table = "creative_works"
      data_set_history = DataCycleCore::CreativeWork::History.new
      ActiveRecord::Base.transaction do
        # save data_set to history
        data_set_history.creative_work_id = data_set.id
        data_set.attributes.except("id").each do |key,value|
          data_set_history.send("#{key}=", value)
        end
        data_set_history.history_valid = (data_set.updated_at .. save_time)
        data_set_history.save

        # save all relations to classifications to history
        data_set.classification_creative_works.each do |item|
          data_set_classification_history = DataCycleCore::ClassificationCreativeWork::History.new
          data_set_classification_history.creative_work_history_id = data_set_history.id
          data_set_history_valid = (item.updated_at .. save_time)
          data_set_classification_history.history_valid = data_set_history_valid
          item.attributes.except("id","creative_work_id").each do |key,value|
            data_set_classification_history.send("#{key}=", value)
          end
          data_set_classification_history.classification_id = item.classification_id
          data_set_classification_history.save
        end

        # # save all relations to other contents to history
        (DataCycleCore.content_tables - ['creative_works']).map(&:singularize).each do |content_name|
          content_relation_table = [content_name, 'creative_work'].sort.join('_')
          data_set.send(content_name.pluralize).each do |content_item|
            content_item_history_hash = {}
            content_item.attributes.except("id").each do |key,value|
              content_item_history_hash[key] = value
            end
            content_item_history_hash[content_name+"_id"] = content_item.id
            content_item_history_hash["history_valid"] = (content_item.updated_at .. save_time)
            data_set_history.send("#{content_name}_histories").create(content_item_history_hash)
          end
        end
        data_set_history.save
      end
######################################################################################


      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::Place.count - template_place_count)
      assert_equal(1, DataCycleCore::Place::Translation.count - template_place_t_count)
      assert_equal(1, DataCycleCore::CreativeWorkPlace.count)
      assert_equal(1, DataCycleCore::CreativeWorkPlace::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(1, DataCycleCore::Place::History.count)
      assert_equal(1, DataCycleCore::Place::History::Translation.count)


      expected_hash = data_set.get_data_hash
      returned_history = data_set_history.get_data_hash

      assert_equal(expected_hash, returned_data_hash)
    end



  end
end
