# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContainerTest < ActiveSupport::TestCase
    test 'insert container and delete it' do
      template = DataCycleCore::Thing.count
      template_trans = DataCycleCore::Thing::Translation.count
      current_user = DataCycleCore::User.first

      data_set = DataCycleCore::TestPreparations.data_set_object('Container')
      data_set.save!
      data_hash = { 'name' => 'Test Thema!' }
      error = data_set.set_data_hash(data_hash: data_hash, prevent_history: true, current_user: current_user)

      returned_data_hash = data_set.get_data_hash
      assert_equal(data_hash, returned_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(current_user.id, data_set.updated_by)
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::Thing.count - template)
      assert_equal(1, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::Search.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)

      t_a = DataCycleCore::Thing.find_by(template: true, template_name: 'Artikel')
      ds_a = DataCycleCore::Thing.new
      ds_a.schema = t_a.schema
      ds_a.template_name = t_a.template_name
      ds_a.is_part_of = data_set.id
      ds_a.save

      dh_a = {
        'name' => 'Test Artikel!',
        'date_modified' => Time.zone.now
      }
      e_a = ds_a.set_data_hash(data_hash: dh_a, prevent_history: true, current_user: current_user)
      ds_a.save

      r_dh = ds_a.get_data_hash
      e_hash = {
        'name' => 'Test Artikel!',
        'tags' => [],
        'image' => [],
        'textblock' => [],
        'output_channel' => [],
        'quotation' => [],
        'content_location' => []
      }

      assert_equal(e_hash.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')), r_dh.compact.except(*DataCycleCore::TestPreparations.excepted_attributes('creative_work')))
      assert_equal(current_user.id, ds_a.updated_by)
      assert_equal(0, e_a[:error].count)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::Thing.count - template)
      assert_equal(2, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::ClassificationContent.count)
      assert_equal(2, DataCycleCore::Search.count)
      assert_equal(0, DataCycleCore::Thing::History.count)
      assert_equal(0, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)

      assert_equal(1, data_set.children.count)
      data_set.destroy_content(current_user: current_user, save_time: Time.zone.now)

      assert_equal(0, DataCycleCore::Thing.count - template)
      assert_equal(0, DataCycleCore::Thing::Translation.count - template_trans)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Search.count)
      assert_equal(2, DataCycleCore::Thing::History.count)
      assert_equal(2, DataCycleCore::Thing::History::Translation.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
      assert_equal(2, DataCycleCore::ClassificationContent::History.count)

      DataCycleCore::Thing::History.all.each do |item|
        assert_equal(current_user.id, item.updated_by)
        assert_equal(current_user.id, item.updated_by_user.id)
        assert_equal(true, item.updated_at.present?)
        assert_equal(current_user.id, item.deleted_by)
        assert_equal(true, item.deleted_at.present?)
        assert_equal(true, item.deleted_at >= item.updated_at)
      end
    end
  end
end
