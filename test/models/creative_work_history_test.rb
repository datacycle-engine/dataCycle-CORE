# frozen_string_literal: true

require 'test_helper'
# TODO: rename to Thing / Content
module DataCycleCore
  class CreativeWorkHistoryTest < ActiveSupport::TestCase
    test "create CreativeWork and don't store History" do
      template_count = DataCycleCore::Thing.count
      template_trans_count = DataCycleCore::Thing::Translation.count

      data_hash = { 'name' => 'Dies ist ein Test!' }
      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'TestSimple', data_hash: data_hash, prevent_history: true)
      save_time = Time.zone.now
      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.except('id').compact)
      assert_equal(0, data_set.errors.messages.size)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Thing.count - template_count)
      assert_equal(1, DataCycleCore::Thing::Translation.count - template_trans_count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)

      assert_equal(data_set.get_data_hash(Time.zone.now), data_set.as_of(save_time).get_data_hash(save_time))
    end

    test 'create CreativeWork and store History' do
      template_count = DataCycleCore::Thing.count
      template_trans_count = DataCycleCore::Thing::Translation.count

      data_hash = { 'name' => 'Dies ist ein Test!' }
      save_time = Time.zone.now
      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'TestSimple', data_hash: data_hash, save_time: save_time)
      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.except('id').compact)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Thing.count - template_count)
      assert_equal(1, DataCycleCore::Thing::Translation.count - template_trans_count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)

      assert_equal(data_set.get_data_hash(Time.zone.now), data_set.as_of(save_time).get_data_hash(save_time))
    end

    test 'save data to History with included Object data in translated jsonb field' do
      template_cw_count = DataCycleCore::Thing.count
      template_cwt_count = DataCycleCore::Thing::Translation.count

      data_hash = { 'name' => 'Dies ist ein Test!', 'included_data' => { 'item1' => 'Test item 1', 'item2' => 'Test item 2' } }
      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'TestIncludedData', data_hash: data_hash)

      save_time = Time.zone.now
      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.except('id').compact)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Thing.count - template_cw_count)
      assert_equal(1, DataCycleCore::Thing::Translation.count - template_cwt_count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)

      assert_equal(data_set.get_data_hash, data_set.as_of(save_time).get_data_hash(save_time))
    end

    test 'save data to History with classification' do
      template_count = DataCycleCore::Thing.count
      template_trans_count = DataCycleCore::Thing::Translation.count

      save_time = Time.zone.now - 10.seconds

      template_data = DataCycleCore::Thing.find_by(template: true, template_name: 'TestClassificationData')
      data_set = DataCycleCore::Thing.new
      data_set.schema = template_data.schema
      data_set.template_name = template_data.template_name
      data_set.created_at = save_time
      data_set.updated_at = save_time
      data_set.save

      data_hash = { 'name' => 'Dies ist ein Test!' }
      data_set.set_data_hash(data_hash: data_hash, save_time: save_time + 5.seconds, new_content: true)
      data_set.save

      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.except('id', 'data_pool').compact)

      assert_equal(1, returned_data_hash['data_pool'].count)
      assert_equal(0, data_set.errors.size)
      assert_not_equal(data_set.get_data_hash(Time.zone.now), data_set.get_data_hash(save_time + 2.seconds))

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Thing.count - template_count)
      assert_equal(1, DataCycleCore::Thing::Translation.count - template_trans_count)
      assert_equal(1, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)
    end

    test 'save data to History with embeddedObject from another content_table' do
      template_count = DataCycleCore::Thing.count
      template_trans_count = DataCycleCore::Thing::Translation.count

      save_time = Time.zone.now - 10.seconds

      template_data = DataCycleCore::Thing.find_by(template: true, template_name: 'TestEmbeddedPlaceData')
      data_set = DataCycleCore::Thing.new
      data_set.schema = template_data.schema
      data_set.template_name = template_data.template_name
      data_set.created_at = save_time
      data_set.updated_at = save_time
      data_set.save

      template_place = DataCycleCore::Thing.find_by(template: true, template_name: 'testPlace')
      data_set_place = DataCycleCore::Thing.new
      data_set_place.schema = template_place.schema
      data_set_place.template_name = template_place.template_name
      data_set_place.created_at = save_time
      data_set_place.updated_at = save_time
      data_set_place.save
      data_set_place.set_data_hash(data_hash: { 'name' => 'Das it ein testPlace!' }, save_time: save_time + 2.seconds)
      data_set_place.save

      data_hash = { 'name' => 'Dies ist ein Test!', 'test_place' => [{ 'id' => data_set_place.id }] }
      data_set.set_data_hash(data_hash: data_hash, save_time: save_time + 4.seconds)
      data_set.save

      returned_data_hash = data_set.get_data_hash
      expected_hash = data_hash
      expected_hash['test_place'][0] = data_set_place.get_data_hash
      assert_equal(data_hash, returned_data_hash.except('id'))
      assert_equal(0, data_set.errors.size)

      returned_data_hash = data_set.get_data_hash(data_set.updated_at + 3.seconds)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::Thing.count - template_count)
      assert_equal(2, DataCycleCore::Thing::Translation.count - template_trans_count)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)

      assert_equal(expected_hash, returned_data_hash.except('id'))
    end

    test 'save data to History with embeddedObject from same content_table' do
      template_count = DataCycleCore::Thing.count
      template_trans_count = DataCycleCore::Thing::Translation.count

      save_time = Time.zone.now - 64.seconds

      template_data = DataCycleCore::Thing.find_by(template: true, template_name: 'TestEmbeddedCreativeWork')
      data_set = DataCycleCore::Thing.new
      data_set.schema = template_data.schema
      data_set.template_name = template_data.template_name
      data_set.created_at = save_time
      data_set.updated_at = save_time
      data_set.save

      template_cw = DataCycleCore::Thing.find_by(template: true, template_name: 'EmbeddedCreativeWork')
      data_set_cw = DataCycleCore::Thing.new
      data_set_cw.schema = template_cw.schema
      data_set_cw.template_name = template_cw.template_name
      data_set_cw.created_at = save_time
      data_set_cw.updated_at = save_time
      data_set_cw.save

      data_set_cw.set_data_hash(data_hash: { 'name' => 'eingebettete Kreativdaten' }, current_user: nil, save_time: save_time + 2.seconds, new_content: true)

      data_hash = { 'name' => 'Dies ist ein Test!', 'test_cw' => [{ 'id' => data_set_cw.id }] }
      data_set.set_data_hash(data_hash: data_hash, current_user: nil, save_time: save_time + 4.seconds, new_content: true)

      returned_data_hash = data_set.get_data_hash
      expected_hash = data_hash
      expected_hash['test_cw'][0] = data_set_cw.get_data_hash
      assert_equal(data_hash, returned_data_hash.except('id'))
      assert_equal(0, data_set.errors.size)

      new_data_hash = { 'name' => 'Neuer aktueller Datensatz!', 'test_cw' => [{ 'id' => data_set_cw.id }] }
      data_set.set_data_hash(data_hash: new_data_hash, current_user: nil, save_time: save_time + 8.seconds)

      new_data_hash['test_cw'][0] = data_set_cw.get_data_hash
      data_set_new = data_set.get_data_hash
      data_set_history = data_set.get_data_hash(save_time + 6.seconds)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::Thing.count - template_count)
      assert_equal(2, DataCycleCore::Thing::Translation.count - template_trans_count)
      assert_equal(1, DataCycleCore::ClassificationContent.count)
      assert_equal(2, DataCycleCore::Thing::History.count)
      assert_equal(2, DataCycleCore::Thing::History::Translation.count)
      assert_equal(1, DataCycleCore::ClassificationContent::History.count)

      assert_equal(new_data_hash, data_set_new.except('id'))
      assert_equal(expected_hash, data_set_history.except('id'))
    end

    test 'create CreativeWork and store multiple Histories to test as_of method' do
      template_count = DataCycleCore::Thing.count
      template_trans_count = DataCycleCore::Thing::Translation.count

      template_data = DataCycleCore::Thing.find_by(template: true, template_name: 'TestSimple')
      data_set = DataCycleCore::Thing.new
      data_set.schema = template_data.schema
      data_set.template_name = template_data.template_name
      data_set.name = 'initial'
      data_set.updated_at = Time.zone.now - 5.weeks
      data_set.created_at = data_set.updated_at
      data_set.save

      weeks4ago = Time.zone.now - 4.weeks
      data_hash_4w = { 'name' => 'Test 4.weeks.ago!' }
      data_set.set_data_hash(data_hash: data_hash_4w, current_user: nil, save_time: weeks4ago)
      data_set.updated_at = weeks4ago
      data_set.save

      weeks3ago = Time.zone.now - 3.weeks
      data_hash_3w = { 'name' => 'Test 3.weeks.ago!' }
      data_set.set_data_hash(data_hash: data_hash_3w, current_user: nil, save_time: weeks3ago)
      data_set.updated_at = weeks3ago
      data_set.save

      weeks2ago = Time.zone.now - 2.weeks
      data_hash_2w = { 'name' => 'Test 2.weeks.ago!' }
      data_set.set_data_hash(data_hash: data_hash_2w, current_user: nil, save_time: weeks2ago)
      data_set.updated_at = weeks2ago
      data_set.save

      weeks1ago = Time.zone.now - 1.week
      data_hash_1w = { 'name' => 'Test 1.weeks.ago!' }
      data_set.set_data_hash(data_hash: data_hash_1w, current_user: nil, save_time: weeks1ago)
      data_set.updated_at = weeks1ago
      data_set.save

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Thing.count - template_count)
      assert_equal(1, DataCycleCore::Thing::Translation.count - template_trans_count)
      assert_equal(3, DataCycleCore::Thing::History.count)
      assert_equal(3, DataCycleCore::Thing::History::Translation.count)

      assert_equal(data_hash_1w, data_set.get_data_hash.except('id'))
      assert_equal(data_hash_1w, data_set.get_data_hash(Time.zone.now).except('id'))
      assert_equal(data_hash_2w, data_set.get_data_hash(weeks1ago - 1.day).except('id'))
      assert_equal(data_hash_3w, data_set.get_data_hash(weeks2ago - 1.day).except('id'))
      assert_equal(data_hash_4w, data_set.get_data_hash(weeks3ago - 1.day).except('id'))
      assert_equal(data_hash_4w, data_set.get_data_hash(weeks4ago + 1.day).except('id'))
      assert_nil(data_set.as_of(weeks4ago - 2.weeks))
      assert_nil(data_set.as_of(Time.zone.now - 3.months))
      assert_equal(data_hash_1w, data_set.get_data_hash(Time.zone.now + 1.month).except('id'))
      # assert_equal({ 'name' => ['~', 'Test 1.weeks.ago!', 'Test 4.weeks.ago!'] }, data_set.diff(data_set.get_data_hash(weeks4ago + 1.day)))
      # assert_equal({ 'name' => ['~', 'Test 2.weeks.ago!', 'Test 3.weeks.ago!'] }, data_set.as_of(weeks1ago - 1.day).diff(data_set.get_data_hash(weeks2ago - 1.day)))
    end

    test 'save creative work with embeddedLink to history' do
      template = DataCycleCore::Thing.count
      template_trans = DataCycleCore::Thing::Translation.count

      data_set = DataCycleCore::TestPreparations.create_content(template_name: 'CreativeWorkEmbeddedLink', data_hash: { 'name' => 'Test Link' })
      data_place_id1 = DataCycleCore::TestPreparations.create_content(template_name: 'testPlace', data_hash: { 'name' => 'Test place 1' }).id
      data_place_id2 = DataCycleCore::TestPreparations.create_content(template_name: 'testPlace', data_hash: { 'name' => 'Test place 2' }).id

      assert_equal(3, DataCycleCore::Thing.count - template)
      assert_equal(3, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(data_hash: { 'name' => 'Test Link', 'linked' => [data_place_id1] })

      assert_equal(0, data_set.errors.size)
      assert_equal(3, DataCycleCore::Thing.count - template)
      assert_equal(3, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::Thing::History.count)
      assert_equal(1, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(data_hash: { 'name' => 'Test Link2', 'linked' => [data_place_id2] })

      assert_equal(0, data_set.errors.size)
      assert_equal(3, DataCycleCore::Thing.count - template)
      assert_equal(3, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::Thing::History.count)
      assert_equal(2, DataCycleCore::Thing::History::Translation.count)
      assert_equal(1, DataCycleCore::ContentContent::History.count)

      data_set.set_data_hash(data_hash: { 'name' => 'Test Link1', 'linked' => [data_place_id1] })
      data_set.save

      assert_equal(0, data_set.errors.size)
      assert_equal(3, DataCycleCore::Thing.count - template)
      assert_equal(3, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(1, DataCycleCore::ContentContent.count)
      assert_equal(3, DataCycleCore::Thing::History.count)
      assert_equal(3, DataCycleCore::Thing::History::Translation.count)
      assert_equal(2, DataCycleCore::ContentContent::History.count)

      assert_equal([data_place_id2, data_place_id1].sort, data_set.histories.map { |item| item.linked.ids }.flatten.sort)
    end
  end
end
