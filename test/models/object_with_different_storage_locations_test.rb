# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ObjectWithDifferentStorageLocationsTest < ActiveSupport::TestCase
    test 'events template with daterange' do
      template = DataCycleCore::Thing.find_by(template: true, template_name: 'Event')
      data_set = DataCycleCore::Thing.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save

      data_hash = {
        'url' => 'http://www.wtf.at',
        'event_period' => {
          'start_date' => '2017-07-18 12:00',
          'end_date' => '2017-10-29 12:00'
        }
      }

      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash.compact
      expected_hash = {
        'url' => 'http://www.wtf.at',
        'image' => [],
        'content_location' => [],
        'sub_event' => [],
        'output_channel' => [],
        'tags' => [],
        'overlay' => [],
        'event_period' => {
          'start_date' => '2017-07-18 12:00'.to_datetime.to_s(:db),
          'end_date' => '2017-10-29 12:00'.to_datetime.to_s(:db)
        }
      }
      returned_data_hash['event_period'].each do |key, value|
        returned_data_hash['event_period'][key] = value.to_datetime.to_s(:db)
      end
      assert_equal(expected_hash, returned_data_hash.except(*DataCycleCore::TestPreparations.excepted_attributes))
      assert_equal(0, error[:error].count)
    end

    test 'save Object in metadata and data within object to column' do
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'TestObject')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_hash = {
        'headline1' => 'Dies ist ein Test!',
        'description1' => 'wtf is going on???',
        'period' => {
          'created_at' => '2017-06-01',
          'updated_at' => '2017-07-01'
        }
      }
      error = data_set.set_data_hash(data_hash: data_hash)
      data_set.save
      returned_data_hash = data_set.get_data_hash
      expected_hash = {
        'headline1' => 'Dies ist ein Test!',
        'description1' => 'wtf is going on???',
        'period' => {
          'created_at' => '2017-06-01'.to_datetime.to_s(:db),
          'updated_at' => '2017-07-01'.to_datetime.to_s(:db)
        }
      }
      returned_data_hash['period'].each do |key, value|
        returned_data_hash['period'][key] = value.to_datetime.to_s(:db)
      end
      returned_data_hash['period']['updated_at'] = '2017-07-01'.to_datetime.to_s(:db)
      assert_equal(expected_hash, returned_data_hash)
      assert_equal(0, error[:error].count)
    end

    test 'save Object in metadata and data within object to column and next level object' do
      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'TestObject2')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save
      data_hash = {
        'headline1' => 'Dies ist ein Test!',
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
        'headline1' => 'Dies ist ein Test!',
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
      assert_equal(expected_hash, returned_data_hash)
      assert_equal(0, error[:error].count)
    end
  end
end
