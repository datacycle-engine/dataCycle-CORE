# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentDiffTest < ActiveSupport::TestCase
    test 'diff of a CreativeWork(Bild) and a hash' do
      template_cw = DataCycleCore::CreativeWork.count
      template_cwt = DataCycleCore::CreativeWork::Translation.count
      template_p = DataCycleCore::Place.count
      template_pt = DataCycleCore::Place::Translation.count

      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Bild')
      content_data = DataCycleCore::CreativeWork.new
      content_data.schema = template.schema
      content_data.template_name = template.template_name
      content_data.save

      data_hash = {
        'headline' => 'Dies ist ein Test!',
        'description' => 'wtf is going on???',
        'content_location' => [{
          'headline' => 'Testort',
          'longitude' => 13.10,
          'latitude' => 25.30
        }]
      }
      content_data.set_data_hash(data_hash: data_hash, prevent_history: true)
      content_data.save
      content_hash = content_data.get_data_hash

      expected_hash = {
        'access' => [],
        'creator' => [],
        'headline' => 'Dies ist ein Test!',
        'description' => 'wtf is going on???',
        'content_location' => [{
          'id' => content_hash.dig('content_location', 0, 'id'),
          'headline' => 'Testort',
          'latitude' => 25.3,
          'location' => nil,
          'longitude' => 13.1,
          'external_source_id' => nil
        }]
      }

      diff = content_data.diff(content_hash)
      assert_equal({}, diff)
      assert_equal(false, content_data.diff?(content_hash))

      diff = content_data.diff(expected_hash)
      assert_equal(
        {
          'data_pool' => [['-', content_data.data_pool.ids]],
          'data_type' => [['-', content_data.data_type.ids]]
        },
        diff
      )
      assert_equal(true, content_data.diff?(expected_hash))

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::Place.count - template_p)
      assert_equal(1, DataCycleCore::Place::Translation.count - template_pt)

      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
      assert_equal(0, DataCycleCore::Place::History.count)
      assert_equal(0, DataCycleCore::Place::History::Translation.count)

      update_hash = {
        'access' => [],
        'creator' => [],
        'headline' => 'change headline',
        'description' => 'change description',
        'content_location' => [{
          'id' => content_hash.dig('content_location', 0, 'id')
        }],
        'data_pool' => content_data.data_pool.ids,
        'data_type' => content_data.data_type.ids
      }
      diff_hash = {
        'headline' =>    ['~', 'Dies ist ein Test!', 'change headline'],
        'description' => ['~', 'wtf is going on???', 'change description']
      }
      diff_hash_t = {
        'headline' =>    ['~', 'change headline', 'Dies ist ein Test!'],
        'description' => ['~', 'change description', 'wtf is going on???']
      }

      assert_equal(true, content_data.diff?(update_hash))
      assert_equal(diff_hash, content_data.diff(update_hash))
      content_data.set_data_hash(data_hash: update_hash)
      content_data.save

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::Place.count - template_p)
      assert_equal(1, DataCycleCore::Place::Translation.count - template_pt)

      assert_equal(1, DataCycleCore::CreativeWork::History.count)
      assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(2, DataCycleCore::ClassificationContent::History.count)
      assert_equal(1, DataCycleCore::ContentContent::History.count)
      assert_equal(1, DataCycleCore::Place::History.count)
      assert_equal(1, DataCycleCore::Place::History::Translation.count)

      history_data = content_data.histories.first
      history_data_hash = history_data.get_data_hash
      assert_equal(false, history_data.diff?(content_hash))
      assert_equal(true,  history_data.diff?(content_data.get_data_hash))
      assert_equal(true,  content_data.diff?(history_data_hash))

      assert_equal(diff_hash,   history_data.diff(content_data.get_data_hash))
      assert_equal(diff_hash_t, content_data.diff(history_data.get_data_hash))
    end
  end
end
