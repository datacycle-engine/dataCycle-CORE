# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentDiffTest < ActiveSupport::TestCase
    test 'diff of a CreativeWork(Bild) and a hash' do
      template = DataCycleCore::Thing.count
      template_trans = DataCycleCore::Thing::Translation.count
      data_hash = {
        'name' => 'Dies ist ein Test!',
        'description' => 'wtf is going on???'
      }
      content_data = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data_hash)
      content_hash = content_data.get_data_hash

      # diff = content_data.diff(content_hash)
      # assert_equal({}, diff)
      # assert_equal(false, content_data.diff?(content_hash))

      diff = content_data.diff(data_hash)
      diff_hash_if_defaults_are_not_considered = {
        'slug' => ['-', content_data.slug],
        'data_type' => [['-', content_data.data_type.ids]],
        'data_pool' => [['-', content_data.data_pool.ids]],
        'upload_date' => ['-', content_data.upload_date],
        'mandatory_license' => ['-', false],
        'schema_types' => [['-', content_data.schema_types.ids]]
      }
      assert_equal(diff_hash_if_defaults_are_not_considered, diff)

      partial_schema_hash = content_data.schema.dup
      partial_schema_hash['properties'] = content_data.property_definitions&.slice(*data_hash.keys)
      assert_equal(false, content_data.diff?(data_hash, partial_schema_hash))
      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Thing.count - template)
      assert_equal(1, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(3, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)

      update_hash = {
        'access' => [],
        'name' => 'change headline',
        'description' => 'change description'
      }

      diff_hash = {
        'name' => ['~', 'Dies ist ein Test!', 'change headline'],
        'description' => ['~', 'wtf is going on???', 'change description']
      }
      diff_hash_t = {
        'name' => ['~', 'change headline', 'Dies ist ein Test!'],
        'description' => ['~', 'change description', 'wtf is going on???']
      }

      partial_schema_hash = content_data.schema.dup
      partial_schema_hash['properties'] = content_data.property_definitions&.slice(*update_hash.keys)

      assert_equal(true, content_data.diff?(update_hash, partial_schema_hash))
      assert_equal(diff_hash, content_data.diff(update_hash, partial_schema_hash))
      content_data.set_data_hash(data_hash: update_hash, partial_update: true)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Thing.count - template)
      assert_equal(1, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(3, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::Thing::History.count)
      assert_equal(1, DataCycleCore::Thing::History::Translation.count)
      assert_equal(3, DataCycleCore::ClassificationContent::History.count)

      history_data = content_data.histories.first
      history_data_hash = history_data.get_data_hash
      assert_equal(false, history_data.diff?(content_hash))
      assert_equal(true,  history_data.diff?(content_data.get_data_hash))
      assert_equal(true,  content_data.diff?(history_data_hash))

      assert_equal(diff_hash,   history_data.diff(content_data.get_data_hash))
      assert_equal(diff_hash_t, content_data.diff(history_data.get_data_hash))

      history_hash = history_data.get_data_hash
      assert_equal(diff_hash_t, content_data.diff(history_hash))
    end
    # TODO: add test incl. embedded + linked
    # test 'diff of a CreativeWork(Bild) and a hash' do
    #   template_cw = DataCycleCore::CreativeWork.count
    #   template_cwt = DataCycleCore::CreativeWork::Translation.count
    #   template_p = DataCycleCore::Place.count
    #   template_pt = DataCycleCore::Place::Translation.count
    #
    #   template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Bild')
    #   content_data = DataCycleCore::CreativeWork.new
    #   content_data.schema = template.schema
    #   content_data.template_name = template.template_name
    #   content_data.save
    #
    #   data_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_url' => 'http://www.wtf.at'
    #   }
    #   content_data.set_data_hash(data_hash: data_hash, prevent_history: true)
    #   content_hash = content_data.get_data_hash
    #
    #   expected_hash = {
    #     'headline' => 'Dies ist ein Test!',
    #     'description' => 'wtf is going on???',
    #     'content_url' => 'http://www.wtf.at'
    #   }
    #
    #   diff = content_data.diff(content_hash)
    #   assert_equal({}, diff)
    #   assert_equal(false, content_data.diff?(content_hash))
    #
    #   diff = content_data.diff(expected_hash)
    #   _diff_hash_if_defaults_are_not_considered = {
    #     'data_type' => [['-', content_data.data_type.ids]]
    #   }
    #   assert_equal({}, diff)
    #   assert_equal(false, content_data.diff?(expected_hash))
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
    #   assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    #   assert_equal(2, DataCycleCore::ClassificationContent.count)
    #   assert_equal(1, DataCycleCore::Place.count - template_p)
    #   assert_equal(1, DataCycleCore::Place::Translation.count - template_pt)
    #
    #   assert_equal(0, DataCycleCore::CreativeWork::History.count)
    #   assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)
    #   assert_equal(0, DataCycleCore::ClassificationContent::History.count)
    #   assert_equal(0, DataCycleCore::ContentContent::History.count)
    #   assert_equal(0, DataCycleCore::Place::History.count)
    #   assert_equal(0, DataCycleCore::Place::History::Translation.count)
    #
    #   update_hash = {
    #     'access' => [],
    #     'creator' => [],
    #     'headline' => 'change headline',
    #     'description' => 'change description',
    #     'content_location' => [{
    #       'id' => content_hash.dig('content_location', 0, 'id')
    #     }],
    #     'data_pool' => content_data.data_pool.ids,
    #     'data_type' => content_data.data_type.ids
    #   }
    #   diff_hash = {
    #     'headline' =>    ['~', 'Dies ist ein Test!', 'change headline'],
    #     'description' => ['~', 'wtf is going on???', 'change description']
    #   }
    #   diff_hash_t = {
    #     'headline' =>    ['~', 'change headline', 'Dies ist ein Test!'],
    #     'description' => ['~', 'change description', 'wtf is going on???']
    #   }
    #
    #   assert_equal(true, content_data.diff?(update_hash))
    #   assert_equal(diff_hash, content_data.diff(update_hash))
    #   content_data.set_data_hash(data_hash: update_hash)
    #
    #   # check consistency of data in DB
    #   assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
    #   assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
    #   assert_equal(1, DataCycleCore::ContentContent.count)
    #   assert_equal(2, DataCycleCore::ClassificationContent.count)
    #   assert_equal(1, DataCycleCore::Place.count - template_p)
    #   assert_equal(1, DataCycleCore::Place::Translation.count - template_pt)
    #
    #   assert_equal(1, DataCycleCore::CreativeWork::History.count)
    #   assert_equal(1, DataCycleCore::CreativeWork::History::Translation.count)
    #   assert_equal(2, DataCycleCore::ClassificationContent::History.count)
    #   assert_equal(1, DataCycleCore::ContentContent::History.count)
    #   assert_equal(1, DataCycleCore::Place::History.count)
    #   assert_equal(1, DataCycleCore::Place::History::Translation.count)
    #
    #   history_data = content_data.histories.first
    #   history_data_hash = history_data.get_data_hash
    #   assert_equal(false, history_data.diff?(content_hash))
    #   assert_equal(true,  history_data.diff?(content_data.get_data_hash))
    #   assert_equal(true,  content_data.diff?(history_data_hash))
    #
    #   assert_equal(diff_hash,   history_data.diff(content_data.get_data_hash))
    #   assert_equal(diff_hash_t, content_data.diff(history_data.get_data_hash))
    #
    #   history_hash = history_data.get_data_hash
    #   history_hash['content_location'] = history_data.content_location
    #   assert_equal(diff_hash_t, content_data.diff(history_hash))
    # end

    test 'make sure data are not saved if nothing has changed' do
      template = DataCycleCore::Thing.count
      template_trans = DataCycleCore::Thing::Translation.count
      data_hash = { 'name' => 'Dies ist ein Test!', 'description' => 'wtf is going on???' }
      content_data = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: data_hash, prevent_history: true)
      content_hash = content_data.get_data_hash
      updated_at = content_data.updated_at.to_s(:long_usec)
      created_at = content_data.created_at.to_s(:long_usec)

      diff = content_data.diff(content_hash)
      assert_equal({}, diff)

      partial_schema_hash = content_data.schema.dup
      partial_schema_hash['properties'] = content_data.property_definitions&.slice(*data_hash.keys)
      assert_equal(false, content_data.diff?(data_hash, partial_schema_hash))

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Thing.count - template)
      assert_equal(1, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(3, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)

      content_data.set_data_hash(data_hash: content_hash)

      assert_equal(updated_at, content_data.updated_at.to_s(:long_usec))
      assert_equal(created_at, content_data.created_at.to_s(:long_usec))

      assert_equal(1, DataCycleCore::Thing.count - template)
      assert_equal(1, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(3, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)

      content_data.set_data_hash(data_hash: content_hash)

      assert_equal(updated_at, content_data.updated_at.to_s(:long_usec))
      assert_equal(created_at, content_data.created_at.to_s(:long_usec))

      assert_equal(1, DataCycleCore::Thing.count - template)
      assert_equal(1, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(3, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)
    end
  end
end
