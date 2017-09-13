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
      data_set_history = data_set.to_history(Time.zone.now)

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

      # save to History table
      data_set_history = data_set.to_history(Time.zone.now)

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

      data_set_history = data_set.to_history(Time.zone.now)

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

      data_set_history = data_set.to_history(Time.zone.now)

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

    test "save data to History with embeddedObject from same content_table" do

      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count
      template_place_count = DataCycleCore::Place.count
      template_place_t_count = DataCycleCore::Place::Translation.count

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestEmbeddedCreativeWork", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.save

      template_cw = DataCycleCore::CreativeWork.find_by(template: true, headline: "EmbeddedCreativeWork", description: "CreativeWork")
      validation_cw_hash = template_cw.metadata['validation']
      data_set_cw = DataCycleCore::CreativeWork.new
      data_set_cw.metadata = { 'validation' => validation_cw_hash }
      data_set_cw.save
      data_set_cw.set_data_hash({"headline" => "eingebettete Kreativdaten"})
      data_set_cw.save

      data_hash = { "headline" => "Dies ist ein Test!", "testCW" => [{"id" => data_set_cw.id}]}
      error = data_set.set_data_hash(data_hash)
      data_set.save

      returned_data_hash = data_set.get_data_hash
      expected_hash = data_hash
      expected_hash['testCW'][0] = data_set_cw.get_data_hash
      assert_equal(data_hash, returned_data_hash)
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(2, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::ClassificationCreativeWork.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationCreativeWork::History.count)

      data_set_history = data_set.to_history(Time.zone.now)

      assert_equal(2, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(2, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::ClassificationCreativeWork.count)
      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(2, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(1, DataCycleCore::ClassificationCreativeWork::History.count)

      expected_hash = data_set.get_data_hash
      returned_history = data_set_history.get_data_hash

      assert_equal(expected_hash, returned_data_hash)
    end

    test "create CreativeWork and store multiple Histories to test as_of method" do

      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestSimple", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.save
      data_hash_4w = { "headline" => "Test 4.weeks.ago!" }
      error = data_set.set_data_hash(data_hash_4w)
      weeks4ago = Time.zone.now-4.weeks
      data_set.updated_at = weeks4ago
      data_set.save

      weeks3ago = Time.zone.now-3.weeks
      data_set_history = data_set.to_history(weeks3ago)
      data_hash_3w = {"headline" => "Test 3.weeks.ago!"}
      data_set.set_data_hash(data_hash_3w)
      data_set.updated_at = weeks3ago
      data_set.save

      weeks2ago = Time.zone.now-2.weeks
      data_set_history = data_set.to_history(weeks2ago)
      data_hash_2w = {"headline" => "Test 2.weeks.ago!"}
      data_set.set_data_hash(data_hash_2w)
      data_set.updated_at = weeks2ago
      data_set.save

      weeks1ago = Time.zone.now-1.week
      data_set_history = data_set.to_history(weeks1ago)
      data_hash_1w = {"headline" => "Test 1.weeks.ago!"}
      data_set.set_data_hash(data_hash_1w)
      data_set.updated_at = weeks1ago
      data_set.save

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(3, DataCycleCore::CreativeWork::History.count)
      assert_equal(3, DataCycleCore::CreativeWork::History::Translation.count)

      # history_table = DataCycleCore::CreativeWork::History.arel_table
      # history_table_translation = DataCycleCore::CreativeWork::History::Translation.arel_table
      # ap data_set.histories.
      #   joins(
      #     history_table.join(history_table_translation).
      #     on(history_table[:id].eq(history_table_translation[:creative_work_history_id])).
      #     join_sources
      #   ).pluck(:headline, :history_valid)

      assert_equal(data_hash_1w, data_set.get_data_hash)
      assert_equal(data_hash_1w, data_set.as_of(Time.zone.now).get_data_hash)
      assert_equal(data_hash_2w, data_set.as_of(weeks1ago-1.day).get_data_hash)
      assert_equal(data_hash_3w, data_set.as_of(weeks2ago-1.day).get_data_hash)
      assert_equal(data_hash_4w, data_set.as_of(weeks3ago-1.day).get_data_hash)
      assert_equal(data_hash_4w, data_set.as_of(weeks4ago).get_data_hash)
      assert_nil(data_set.as_of(weeks4ago-1.week))
      assert_nil(data_set.as_of(Time.zone.now-3.months))
      assert_equal(data_hash_1w, data_set.as_of(Time.zone.now+1.month).get_data_hash)

    end


  end
end
