# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Filter
    class UpdatedSinceBiTest < ActiveSupport::TestCase
      include DataCycleCore::DataHelper

      test 'sanity check for updated_since' do
        _, timestamp = data_setup(bi: 2)

        assert_equal(3, DataCycleCore::Thing.where('things.template = false AND things.updated_at >= ?', timestamp).count)
        assert_equal(0, DataCycleCore::Thing.where('things.template = false AND things.updated_at > ?', Time.zone.now).count)
        assert_equal(3, DataCycleCore::Filter::Search.new.updated_since(timestamp - 1.minute).count)
        assert_equal(0, DataCycleCore::Filter::Search.new.updated_since(Time.zone.now).count)
      end

      test 'set updated_at at linked data and find main thing' do
        data_set, timestamp = data_setup(bi: 2)
        linked_objects = data_set.linked_place.pluck(:id)

        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(timestamp).count)
        new_timestamp = Time.zone.now
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)

        linked_item = DataCycleCore::Thing.find(linked_objects.last)
        linked_item.updated_at = new_timestamp
        linked_item.save!

        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)
      end

      test 'set updated_at at linked data and find main thing then remove link --> do not find it again' do
        data_set, timestamp = data_setup(bi: 2)
        linked_objects = data_set.linked_place.pluck(:id)
        new_timestamp = Time.zone.now
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)

        linked_item = DataCycleCore::Thing.find(linked_objects.last)
        linked_item.updated_at = new_timestamp
        linked_item.save!

        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)
        data_set.set_data_hash(data_hash: { 'linked_place' => linked_objects.first }, partial_update: true, save_time: timestamp)
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)
      end

      test 'two links to same item, remove links one after another' do
        data_set, timestamp = data_setup(one: 1)
        linked = data_set.linked_main_place.first
        data_set.set_data_hash(data_hash: { 'linked_main2_place' => [linked.id] }, partial_update: true, save_time: timestamp)
        new_timestamp = Time.zone.now
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)

        linked.updated_at = new_timestamp
        linked.save!
        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)

        data_set.set_data_hash(data_hash: { 'linked_main_place' => [] }, partial_update: true, save_time: timestamp)
        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)

        data_set.set_data_hash(data_hash: { 'linked_main2_place' => [] }, partial_update: true, save_time: timestamp)
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)
      end

      test 'two links to same item, remove links first bi-diretional then single' do
        data_set, timestamp = data_setup(bi: 1)
        linked_bi = data_set.linked_place.first
        data_set.set_data_hash(data_hash: { 'linked_main_place' => [linked_bi.id] }, partial_update: true, save_time: timestamp)
        new_timestamp = Time.zone.now
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)

        linked_bi.updated_at = new_timestamp
        linked_bi.save!
        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)

        data_set.set_data_hash(data_hash: { 'linked_place' => [] }, partial_update: true, save_time: timestamp)
        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)

        data_set.set_data_hash(data_hash: { 'linked_main_place' => [] }, partial_update: true, save_time: timestamp)
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)
      end

      test 'two links to same item, remove links first single- then bi-diretional' do
        data_set, timestamp = data_setup(bi: 1)
        linked_bi = data_set.linked_place.first
        data_set.set_data_hash(data_hash: { 'linked_main_place' => [linked_bi.id] }, partial_update: true, save_time: timestamp)
        new_timestamp = Time.zone.now
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)

        linked_bi.updated_at = new_timestamp
        linked_bi.save!
        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)

        data_set.set_data_hash(data_hash: { 'linked_main_place' => [] }, partial_update: true, save_time: timestamp)
        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)

        data_set.set_data_hash(data_hash: { 'linked_place' => [] }, partial_update: true, save_time: timestamp)
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Tour-Sync').updated_since(new_timestamp).count)
      end

      private

      def data_setup(one: nil, bi: nil)
        timestamp = Time.zone.now - 1.minute
        linked_objects = create_places(one, timestamp) if one&.positive?
        linked_bi_objects = create_places(bi, timestamp) if bi&.positive?

        data_set = DataCycleCore::TestPreparations.create_content(
          template_name: 'Tour-Sync',
          data_hash: { 'name' => 'Tour-Sync', 'description' => 'Tour-Sync-description' },
          prevent_history: true,
          save_time: timestamp
        )
        data_hash = {}
        data_hash['linked_place'] = linked_bi_objects if linked_bi_objects.present?
        data_hash['linked_main_place'] = linked_objects if linked_objects.present?
        data_set.set_data_hash(data_hash: data_hash, save_time: timestamp)

        return data_set, timestamp
      end

      def create_places(count, timestamp)
        places = []
        count.times do |i|
          places.push(
            DataCycleCore::TestPreparations.create_content(
              template_name: 'Place-Sync',
              data_hash: { 'name' => "Place-Sync-#{i}", 'description' => "Place-Sync-description-#{i}" },
              prevent_history: true,
              save_time: timestamp
            ).id
          )
        end
        places
      end
    end
  end
end
