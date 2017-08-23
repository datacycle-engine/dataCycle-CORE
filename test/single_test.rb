require 'test_helper'

module DataCycleCore
  class SingleTest < ActiveSupport::TestCase

    test "faulty test" do
      template = DataCycleCore::CreativeWork.where(template: true, headline: "Thema", description: "CreativeWork").first
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      expected_hash = {
        "headline" => "Dies ist ein Test!",
        "validityPeriod" => {
          "validFrom" => "2017-05-01",
          "validUntil" => "2017-06-01"
        },
        "tags"=>[],
        "state"=>[],
        "topics"=>[],
        "markets"=>[],
        "season" => [],
        "kind" => []
      }

      data_set.set_data_hash({"headline" => "Dies ist ein Test!", "validityPeriod" => {"validFrom" => "2017-05-01", "validUntil" => "2017-06-01"}})
      data_set.save
      assert_equal(expected_hash, data_set.get_data_hash.compact.except('id',"data_pool"))
      assert_equal( {"validityPeriod" => {"validFrom" => "2017-05-01", "validUntil" => "2017-06-01"}}, data_set.metadata.except('validation').compact)
    end

  end
end
