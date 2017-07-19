require 'test_helper'

module DataCycleCore
  class ObjectWithDifferentLocationsTest < ActiveSupport::TestCase


    test "save Object in metadata and data within object to column" do
      template = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestObject", description: "CreativeWork")
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "period" => {
            "created_at" => "2017-06-01",
            "updated_at" => "2017-07-01"
        }
      }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash = {
        "headline" => "Dies ist ein Test!",
        "description" => "wtf is going on???",
        "period" => {
          "created_at" => "2017-06-01".to_datetime,
          "updated_at" => "2017-07-01".to_datetime
        }
      }
      assert_equal(expected_hash, returned_data_hash)
      assert_equal(0, error[:error].count)
    end

    test "save Object in metadata and data within object to column and next level object" do
      template = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestObject2", description: "CreativeWork")
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline" => "Dies ist ein Test!",
        "period" => {
            "created_at" => "2017-06-01",
            "updated_at" => "2017-07-01",
            "description" => "wtf is going on???",
            "validityPeriod" => {
              "validFrom" => "2017-06-01",
              "validUntil" => "2017-07-01"
            }
        }
      }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash = {
        "headline" => "Dies ist ein Test!",
        "period" => {
          "created_at" => "2017-06-01".to_datetime,
          "updated_at" => "2017-07-01".to_datetime,
          "description" => "wtf is going on???",
          "validityPeriod" => {
            "validFrom" => "2017-06-01",
            "validUntil" => "2017-07-01"
          }
        }
      }
      assert_equal(expected_hash, returned_data_hash)
      assert_equal(0, error[:error].count)
    end

  end
end
