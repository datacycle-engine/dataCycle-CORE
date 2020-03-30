# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ObjectWithDifferentStorageLocationsTest < ActiveSupport::TestCase
    test 'save Object in metadata and data within object to column' do
      data_set = DataCycleCore::TestPreparations.data_set_object('Included-Object-Creative-Work')
      data_set.save!
      data_hash = {
        'name' => 'Dies ist ein Test!',
        'description' => 'wtf is going on???',
        'period' => {
          'created_at' => '2017-06-01',
          'updated_at' => '2017-07-01'
        }
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash = {
        'name' => 'Dies ist ein Test!',
        'description' => 'wtf is going on???',
        'period' => {
          'created_at' => '2017-06-01'.to_datetime.to_s(:db),
          'updated_at' => '2017-07-01'.to_datetime.to_s(:db)
        }
      }
      returned_data_hash['period'].each do |key, value|
        returned_data_hash['period'][key] = value.to_datetime.to_s(:db)
      end
      returned_data_hash['period']['updated_at'] = '2017-07-01'.to_datetime.to_s(:db)
      assert_equal(expected_hash, returned_data_hash.except('id'))
      assert_equal(0, error[:error].count)
    end

    test 'save Object in metadata and data within object to column and next level object' do
      data_set = DataCycleCore::TestPreparations.data_set_object('Nested-Included-Object-Creative-Work')
      data_set.save!
      data_hash = {
        'name' => 'Dies ist ein Test!',
        'period' => {
          'created_at' => '2017-06-01',
          'updated_at' => '2017-07-01',
          'description' => 'wtf is going on???',
          'validity_period' => {
            'valid_from' => '2017-06-01',
            'valid_until' => '2017-07-01'
          }
        }
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash = {
        'name' => 'Dies ist ein Test!',
        'period' => {
          'created_at' => '2017-06-01'.to_datetime.to_s(:db),
          'updated_at' => '2017-07-01'.to_datetime.to_s(:db),
          'description' => 'wtf is going on???',
          'validity_period' => {
            'valid_from' => '2017-06-01'.in_time_zone,
            'valid_until' => '2017-07-01'.in_time_zone
          }
        }
      }
      returned_data_hash['period']['updated_at'] = expected_hash['period']['updated_at']
      returned_data_hash['period']['created_at'] = returned_data_hash['period']['created_at'].to_datetime.to_s(:db)
      assert_equal(expected_hash, returned_data_hash.except('id'))
      assert_equal(0, error[:error].count)
    end
  end
end
