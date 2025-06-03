# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ObjectWithDifferentStorageLocationsTest < ActiveSupport::TestCase
    test 'save Object in metadata and data within object to column' do
      data_hash = {
        'name' => 'Dies ist ein Test!',
        'description' => 'wtf is going on???',
        'period' => {
          'created_at' => '2017-06-01',
          'updated_at' => '2017-07-01'
        }
      }

      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Included-Object-Creative-Work', data_hash:)
      returned_data_hash = data_set.get_data_hash
      expected_hash = {
        'name' => 'Dies ist ein Test!',
        'description' => 'wtf is going on???',
        'period' => {
          'created_at' => '2017-06-01'.to_datetime.to_fs(:db),
          'updated_at' => '2017-07-01'.to_datetime.to_fs(:db)
        },
        'linked_to_text' => []
      }
      returned_data_hash['period'].each do |key, value|
        returned_data_hash['period'][key] = value.to_datetime.to_fs(:db)
      end
      returned_data_hash['period']['updated_at'] = '2017-07-01'.to_datetime.to_fs(:db)
      assert_equal(expected_hash, returned_data_hash.except('id'))
    end

    test 'save Object in metadata and data within object to column and next level object' do
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

      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'Nested-Included-Object-Creative-Work', data_hash:)
      returned_data_hash = data_set.get_data_hash
      expected_hash = {
        'name' => 'Dies ist ein Test!',
        'period' => {
          'created_at' => '2017-06-01'.to_datetime.to_fs(:db),
          'updated_at' => '2017-07-01'.to_datetime.to_fs(:db),
          'description' => 'wtf is going on???',
          'validity_period' => {
            'valid_from' => '2017-06-01'.in_time_zone,
            'valid_until' => '2017-07-01'.in_time_zone
          }
        },
        'linked_to_text' => []
      }
      returned_data_hash['period']['updated_at'] = expected_hash['period']['updated_at']
      returned_data_hash['period']['created_at'] = returned_data_hash['period']['created_at'].to_datetime.to_fs(:db)
      assert_equal(expected_hash, returned_data_hash.except('id'))
      assert_equal(0, data_set.errors.messages.size)
    end
  end
end
