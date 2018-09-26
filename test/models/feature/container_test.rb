# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContainerTest < ActiveSupport::TestCase

    test 'insert container and delete it' do
      template_cw = DataCycleCore::CreativeWork.count
      template_cwt = DataCycleCore::CreativeWork::Translation.count
      current_user = DataCycleCore::User.first

      template = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Container')
      data_set = DataCycleCore::CreativeWork.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set.save

      data_hash = {
        'headline' => 'Test Thema!'
      }
      error = data_set.set_data_hash(data_hash: data_hash, prevent_history: true, current_user: current_user)
      data_set.save

      returned_data_hash = data_set.get_data_hash
      expected_hash = {
        'headline' => 'Test Thema!',
        'output_channel' => [],
        'tags' => []
      }

      assert_equal(expected_hash, returned_data_hash.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))
      assert_equal(current_user.id, data_set.updated_by)
      assert_equal(0, error[:error].count)

      # check consistency of data in DB
      assert_equal(1, DataCycleCore::CreativeWork.count - template_cw)
      assert_equal(1, DataCycleCore::CreativeWork::Translation.count - template_cwt)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(1, DataCycleCore::ClassificationContent.count)
      assert_equal(1, DataCycleCore::Search.count)

      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)

      t_a = DataCycleCore::CreativeWork.find_by(template: true, template_name: 'Artikel')
      ds_a = DataCycleCore::CreativeWork.new
      ds_a.schema = t_a.schema
      ds_a.template_name = t_a.template_name
      ds_a.is_part_of = data_set.id
      ds_a.save

      dh_a = {
        'headline' => 'Test Artikel!',
        'date_modified' => Time.zone.now
      }
      e_a = ds_a.set_data_hash(data_hash: dh_a, prevent_history: true, current_user: current_user)
      ds_a.save

      r_dh = ds_a.get_data_hash
      e_hash = {
        'headline' => 'Test Artikel!',
        'tags' => [],
        'image' => [],
        'textblock' => [],
        'output_channel' => [],
        'quotation' => [],
        'content_location' => []
      }

      assert_equal(e_hash.except(*DataCycleCore::TestPreparations.excepted_attributes), r_dh.compact.except(*DataCycleCore::TestPreparations.excepted_attributes))
      assert_equal(current_user.id, ds_a.updated_by)
      assert_equal(0, e_a[:error].count)

      # check consistency of data in DB
      assert_equal(2, DataCycleCore::CreativeWork.count - template_cw)
      assert_equal(2, DataCycleCore::CreativeWork::Translation.count - template_cwt)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(2, DataCycleCore::ClassificationContent.count)
      assert_equal(2, DataCycleCore::Search.count)

      assert_equal(0, DataCycleCore::CreativeWork::History.count)
      assert_equal(0, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
      assert_equal(0, DataCycleCore::ClassificationContent::History.count)

      assert_equal(1, data_set.children.count)
      data_set.destroy_content(current_user: current_user, save_time: Time.zone.now)

      assert_equal(0, DataCycleCore::CreativeWork.count - template_cw)
      assert_equal(0, DataCycleCore::CreativeWork::Translation.count - template_cwt)
      assert_equal(0, DataCycleCore::ContentContent.count)
      assert_equal(0, DataCycleCore::ClassificationContent.count)
      assert_equal(0, DataCycleCore::Search.count)

      assert_equal(2, DataCycleCore::CreativeWork::History.count)
      assert_equal(2, DataCycleCore::CreativeWork::History::Translation.count)
      assert_equal(0, DataCycleCore::ContentContent::History.count)
      assert_equal(2, DataCycleCore::ClassificationContent::History.count)

      DataCycleCore::CreativeWork::History.all.each do |item|
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
