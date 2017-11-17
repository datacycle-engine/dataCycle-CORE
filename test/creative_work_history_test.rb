require 'test_helper'

module DataCycleCore
  class CreativeWorkHistoryTest < ActiveSupport::TestCase

    test "CreativeWork and History exists" do
      data = DataCycleCore::CreativeWork.new
      assert_equal(data.class, DataCycleCore::CreativeWork)
      data = DataCycleCore::CreativeWork::History.new
      assert_equal(data.class, DataCycleCore::CreativeWork::History)
    end

    test "create CreativeWork and don't store History" do

      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestSimple", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.save
      data_hash = { "headline" => "Dies ist ein Test!" }
      error = data_set.set_data_hash(data_hash: data_hash, prevent_history: true)
      save_time = Time.zone.now
      data_set.save
      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.compact)
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)

      assert_equal(data_set.get_data_hash(Time.zone.now), data_set.as_of(save_time).get_data_hash(save_time))
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
      error = data_set.set_data_hash(data_hash: data_hash)
      save_time = Time.zone.now
      data_set.save
      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.compact)
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)

      assert_equal(data_set.get_data_hash(Time.zone.now), data_set.as_of(save_time).get_data_hash(save_time))
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
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      save_time = Time.zone.now
      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.compact)
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)

      assert_equal(data_set.get_data_hash, data_set.as_of(save_time).get_data_hash(save_time))
    end

    test "save data to History with classification" do

      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count

      save_time = Time.zone.now - 10.seconds

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestClassificationData", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.created_at = save_time
      data_set.updated_at = save_time
      data_set.save

      data_hash = { "headline" => "Dies ist ein Test!"}
      error = data_set.set_data_hash(data_hash: data_hash, save_time: save_time + 5.second)
      data_set.save

      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.except('data_pool').compact)

      assert_equal(1, returned_data_hash['data_pool'].count)
      assert_equal(0, error[:error].count)
      assert_not_equal(data_set.get_data_hash(Time.zone.now), data_set.get_data_hash(save_time + 2.second))

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)
    end

    test "save data to History with embeddedObject from another content_table" do

      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count
      template_place_count = DataCycleCore::Place.count
      template_place_t_count = DataCycleCore::Place::Translation.count

      save_time = Time.zone.now - 10.seconds

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestEmbeddedPlaceData", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.created_at = save_time
      data_set.updated_at = save_time
      data_set.save

      template_place = DataCycleCore::Place.find_by(template: true, headline: "testPlace", description: "Place")
      validation_place_hash = template_place.metadata['validation']
      data_set_place = DataCycleCore::Place.new
      data_set_place.metadata = { 'validation' => validation_place_hash }
      data_set_place.created_at = save_time
      data_set_place.updated_at = save_time
      data_set_place.save
      data_set_place.set_data_hash(data_hash: {"name" => "Das it ein testPlace!"}, save_time: save_time + 2.seconds)
      data_set_place.save


      data_hash = { "headline" => "Dies ist ein Test!", "testPlace" => [{"id" => data_set_place.id}]}
      error = data_set.set_data_hash(data_hash: data_hash, save_time: save_time + 4.seconds)
      data_set.save

      returned_data_hash = data_set.get_data_hash
      expected_hash = data_hash
      expected_hash['testPlace'][0] = data_set_place.get_data_hash
      assert_equal(data_hash, returned_data_hash)
      assert_equal(0, error[:error].count)

      expected_hash = data_set.get_data_hash
      returned_data_hash = data_set.get_data_hash(save_time + 3.seconds)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::Place.count - template_place_count)
      assert_equal(1, DataCycleCore::Place::Translation.count - template_place_t_count)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(1, DataCycleCore::Place::History.count)
      assert_equal(1, DataCycleCore::Place::History::Translation.count)

      expected_hash = {"headline"=>nil, "testPlace"=>[]}
      assert_equal(expected_hash, returned_data_hash)
    end

    test "save data to History with embeddedObject from same content_table" do

      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count
      template_place_count = DataCycleCore::Place.count
      template_place_t_count = DataCycleCore::Place::Translation.count

      save_time = Time.zone.now - 64.seconds

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestEmbeddedCreativeWork", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.created_at = save_time
      data_set.updated_at = save_time
      data_set.save

      template_cw = DataCycleCore::CreativeWork.find_by(template: true, headline: "EmbeddedCreativeWork", description: "CreativeWork")
      validation_cw_hash = template_cw.metadata['validation']
      data_set_cw = DataCycleCore::CreativeWork.new
      data_set_cw.metadata = { 'validation' => validation_cw_hash }
      data_set_cw.created_at = save_time
      data_set_cw.updated_at = save_time
      data_set_cw.save

      data_set_cw.set_data_hash(data_hash: {"headline" => "eingebettete Kreativdaten"}, current_user: nil, save_time: save_time + 2.seconds)
      data_set_cw.save

      data_hash = { "headline" => "Dies ist ein Test!", "testCW" => [{"id" => data_set_cw.id}]}
      error = data_set.set_data_hash(data_hash: data_hash, current_user: nil, save_time: save_time + 4.seconds)
      data_set.save

      returned_data_hash = data_set.get_data_hash
      expected_hash = data_hash
      expected_hash['testCW'][0] = data_set_cw.get_data_hash
      assert_equal(data_hash, returned_data_hash)
      assert_equal(0, error[:error].count)

      new_data_hash = {"headline" => "Neuer aktueller Datensatz!", "testCW" => [{"id" => data_set_cw.id}]}
      data_set.set_data_hash(data_hash: new_data_hash, current_user: nil, save_time: save_time + 8.seconds)
      data_set.save

      new_data_hash["testCW"][0] = data_set_cw.get_data_hash
      data_set_new = data_set.get_data_hash
      data_set_history = data_set.get_data_hash(save_time + 6.seconds)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(2, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::ClassificationContent.count)
      assert_equal(4, DataCycleCore::CreativeWork::History.count)
      assert_equal(4, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(1, DataCycleCore::ClassificationContent::History.count)

      assert_equal(new_data_hash, data_set_new)
      assert_equal(expected_hash, data_set_history)
    end

    test "create CreativeWork and store multiple Histories to test as_of method" do

      template_cw_count = DataCycleCore::CreativeWork.count
      template_cwt_count = DataCycleCore::CreativeWork::Translation.count

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestSimple", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.headline = 'initial'
      data_set.updated_at = Time.zone.now-5.weeks
      data_set.created_at = data_set.updated_at
      data_set.save

      weeks4ago = Time.zone.now-4.weeks
      data_hash_4w = { "headline" => "Test 4.weeks.ago!" }
      error = data_set.set_data_hash(data_hash: data_hash_4w, current_user: nil, save_time: weeks4ago)
      data_set.updated_at = weeks4ago
      data_set.save

      weeks3ago = Time.zone.now-3.weeks
      data_hash_3w = {"headline" => "Test 3.weeks.ago!"}
      data_set.set_data_hash(data_hash: data_hash_3w, current_user: nil, save_time: weeks3ago)
      data_set.updated_at = weeks3ago
      data_set.save

      weeks2ago = Time.zone.now-2.weeks
      data_hash_2w = {"headline" => "Test 2.weeks.ago!"}
      data_set.set_data_hash(data_hash: data_hash_2w, current_user: nil, save_time: weeks2ago)
      data_set.updated_at = weeks2ago
      data_set.save

      weeks1ago = Time.zone.now-1.week
      data_hash_1w = {"headline" => "Test 1.weeks.ago!"}
      data_set.set_data_hash(data_hash: data_hash_1w, current_user: nil, save_time: weeks1ago)
      data_set.updated_at = weeks1ago
      data_set.save

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(4, DataCycleCore::CreativeWork::History.count)
      assert_equal(4, DataCycleCore::CreativeWork::History::Translation.count)


      # puts "#{data_set.id} | #{data_set.updated_at}..#{Time.zone.now} | #{data_set.headline}"
      # data_set.histories.each do |item|
      #   puts "#{item.id} | #{item.history_valid} | #{item.headline}"
      # end
      # history_table = DataCycleCore::CreativeWork::History.arel_table
      # history_table_translation = DataCycleCore::CreativeWork::History::Translation.arel_table
      # ap data_set.histories.
      #   joins(
      #     history_table.join(history_table_translation).
      #     on(history_table[:id].eq(history_table_translation[:creative_work_history_id])).
      #     join_sources
      #   ).pluck(:headline, :history_valid)

      assert_equal(data_hash_1w, data_set.get_data_hash)
      assert_equal(data_hash_1w, data_set.get_data_hash(Time.zone.now))
      assert_equal(data_hash_2w, data_set.get_data_hash(weeks1ago-1.day))
      assert_equal(data_hash_3w, data_set.get_data_hash(weeks2ago-1.day))
      assert_equal(data_hash_4w, data_set.get_data_hash(weeks3ago-1.day))
      assert_equal(data_hash_4w, data_set.get_data_hash(weeks4ago+1.day))
      assert_nil(data_set.as_of(weeks4ago-2.week))
      assert_nil(data_set.as_of(Time.zone.now-3.months))
      assert_equal(data_hash_1w, data_set.get_data_hash(Time.zone.now+1.month))

    end

    test "save creative work with embeddedLink to history" do

      template_cw = DataCycleCore::CreativeWork.count
      template_cwt = DataCycleCore::CreativeWork::Translation.count
      template_p = DataCycleCore::Place.count
      template_pt = DataCycleCore::Place::Translation.count

      template_data = DataCycleCore::CreativeWork.find_by(template: true, headline: "CreativeWorkEmbeddedLink", description: "CreativeWork")
      validation_hash = template_data.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation_hash }
      data_set.save

      template_place = DataCycleCore::Place.find_by(template: true, headline: "testPlace", description: "Place")
      data_place = DataCycleCore::Place.new
      data_place.metadata = { 'validation' => template_place.metadata['validation']}
      data_place.save
      data_place.set_data_hash(data_hash: { "name" => "Test place 1"})
      data_place.save
      data_place_id1 = data_place.id

      template_place = DataCycleCore::Place.find_by(template: true, headline: "testPlace", description: "Place")
      data_place = DataCycleCore::Place.new
      data_place.metadata = { 'validation' => template_place.metadata['validation']}
      data_place.save
      data_place.set_data_hash(data_hash: { "name" => "Test place 2"})
      data_place.save
      data_place_id2 = data_place.id

      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
      assert_equal(2, DataCycleCore::Place.count - template_p)
      assert_equal(2, DataCycleCore::Place::Translation.count - template_pt)
      assert_equal(0, DataCycleCore::CreativeWorkPlace.count)
      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(2, DataCycleCore::Place::History.count)
      assert_equal(2, DataCycleCore::Place::History::Translation.count)
      assert_equal(0, DataCycleCore::CreativeWorkPlace::History.count)

      error = data_set.set_data_hash(data_hash: { "headline" => "Test Link", "linked" => data_place_id1})
      data_set.save

      assert_equal(0, error[:error].size)
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
      assert_equal(2, DataCycleCore::Place.count - template_p)
      assert_equal(2, DataCycleCore::Place::Translation.count - template_pt)
      assert_equal(0, DataCycleCore::CreativeWorkPlace.count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(2, DataCycleCore::Place::History.count)
      assert_equal(2, DataCycleCore::Place::History::Translation.count)
      assert_equal(0, DataCycleCore::CreativeWorkPlace::History.count)

      error = data_set.set_data_hash(data_hash: { "headline" => "Test Link2", "linked" => data_place_id2})
      data_set.save

      assert_equal(0, error[:error].size)
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
      assert_equal(2, DataCycleCore::Place.count - template_p)
      assert_equal(2, DataCycleCore::Place::Translation.count - template_pt)
      assert_equal(0, DataCycleCore::CreativeWorkPlace.count)
      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(2, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(2, DataCycleCore::Place::History.count)
      assert_equal(2, DataCycleCore::Place::History::Translation.count)
      assert_equal(0, DataCycleCore::CreativeWorkPlace::History.count)

      error = data_set.set_data_hash(data_hash: { "headline" => "Test Link1", "linked" => data_place_id1})
      data_set.save

      assert_equal(0, error[:error].size)
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
      assert_equal(2, DataCycleCore::Place.count - template_p)
      assert_equal(2, DataCycleCore::Place::Translation.count - template_pt)
      assert_equal(0, DataCycleCore::CreativeWorkPlace.count)
      assert_equal(3, DataCycleCore::CreativeWork::History.count)
      assert_equal(3, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(2, DataCycleCore::Place::History.count)
      assert_equal(2, DataCycleCore::Place::History::Translation.count)
      assert_equal(0, DataCycleCore::CreativeWorkPlace::History.count)


      assert_equal([data_place_id2, data_place_id1, nil], data_set.histories.map{|item| item.metadata.try(:[],'linked')})

    end


  end
end
