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
      present_history = data_set.history.order(updated_at: :desc)
      last_version = present_history.blank? ? 0 : present_history.first.version

      # save to History table
      data_set_history = DataCycleCore::CreativeWork::History.new
      data_set_history.creative_work_id = data_set.id
      data_set.attributes.except("id").each do |key,value|
        data_set_history.send("#{key}=", value)
      end
      data_set_history.history_valid = (data_set.updated_at .. save_time)
      data_set_history.version = last_version + 1
      data_set_history.save

      ap data_set_history.get_data_hash
      ap data_set_history.history_valid

      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw_count)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt_count)
      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)


      # update data_set with new updated_at == save_time
    end

  end
end
