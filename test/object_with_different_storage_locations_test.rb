require 'test_helper'

module DataCycleCore
  class ObjectWithDifferentStorageLocationsTest < ActiveSupport::TestCase

    test "events template with daterange" do
      template = DataCycleCore::Event.find_by(template: true, headline: "Event", description: "Event")
      validation = template.metadata['validation']
      data_set = DataCycleCore::Event.new
      data_set.metadata = { 'validation' => validation }
      data_set.save

      data_hash = {
        "url" => "estasdfkasdfasfd",
        "eventPeriod" => {
          "startDate"=>"2017-07-18 12:00",
          "endDate"=>"2017-10-29 12:00"
        }
      }

      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash.compact
      expected_hash = {
        "id" => data_set.id,
        "url" => "estasdfkasdfasfd",
        "eventPeriod" => {
          "startDate"=>"2017-07-18 12:00".to_datetime.to_s(:db),
          "endDate"=>"2017-10-29 12:00".to_datetime.to_s(:db)
        }
      }
      returned_data_hash['eventPeriod'].each do |key,value|
        returned_data_hash['eventPeriod'][key] = value.to_datetime.to_s(:db)
      end
      assert_equal(expected_hash, returned_data_hash)
      assert_equal(0, error[:error].count)
    end

    test "save Object in metadata and data within object to column" do
      template = DataCycleCore::CreativeWork.find_by(template: true, headline: "TestObject", description: "CreativeWork")
      validation = template.metadata['validation']
      data_set = DataCycleCore::CreativeWork.new
      data_set.metadata = { 'validation' => validation }
      data_set.save
      data_hash = {
        "headline1" => "Dies ist ein Test!",
        "description1" => "wtf is going on???",
        "period" => {
            "created_at" => "2017-06-01",
            "updated_at" => "2017-07-01"
        }
      }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash = {
        "headline1" => "Dies ist ein Test!",
        "description1" => "wtf is going on???",
        "period" => {
          "created_at" => "2017-06-01".to_datetime.to_s(:db),
          "updated_at" => "2017-07-01".to_datetime.to_s(:db)
        }
      }
      returned_data_hash['period'].each do |key,value|
        returned_data_hash['period'][key] = value.to_datetime.to_s(:db)
      end
      returned_data_hash['period']['updated_at'] = "2017-07-01".to_datetime.to_s(:db)
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
        "headline1" => "Dies ist ein Test!",
        "period" => {
            "created_at" => "2017-06-01",
            "updated_at" => "2017-07-01",
            "description" => "wtf is going on???",
            "validity_period" => {
              "valid_from" => "2017-06-01",
              "valid_until" => "2017-07-01"
            }
        }
      }
      error = data_set.set_data_hash(data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash = {
        "headline1" => "Dies ist ein Test!",
        "period" => {
          "created_at" => "2017-06-01".to_datetime.to_s(:db),
          "updated_at" => "2017-07-01".to_datetime.to_s(:db),
          "description" => "wtf is going on???",
          "validity_period" => {
            "valid_from" => "2017-06-01",
            "valid_until" => "2017-07-01"
          }
        }
      }
      returned_data_hash["period"]['updated_at'] = expected_hash["period"]['updated_at']
      returned_data_hash['period']['created_at'] = returned_data_hash['period']['created_at'].to_datetime.to_s(:db)
      assert_equal(expected_hash, returned_data_hash)
      assert_equal(0, error[:error].count)
    end

  end
end
