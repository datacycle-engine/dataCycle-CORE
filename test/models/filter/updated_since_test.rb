# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Filter
    class UpdatedSinceTest < ActiveSupport::TestCase
      include DataCycleCore::DataHelper
      def setup
        # create entity and add 5 linked entities from the same table
        @things_before = DataCycleCore::Thing.count
        @linked_objects = []
        @timestamp = 1.second.ago
        5.times do |i|
          @linked_objects.push(
            DataCycleCore::TestPreparations.create_content(
              template_name: 'Linked-Creative-Work-2',
              data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked').merge({ 'name' => "CreativeWork Linked Headline #{i}" }),
              prevent_history: true,
              save_time: @timestamp
            ).id
          )
        end
        @data_set = DataCycleCore::TestPreparations.create_content(
          template_name: 'Linked-Creative-Work-1',
          data_hash: DataCycleCore::TestPreparations.load_dummy_data_hash('creative_works', 'linked'),
          prevent_history: true,
          save_time: @timestamp
        )
        @data_set.set_data_hash(
          data_hash: DataCycleCore::TestPreparations
            .load_dummy_data_hash('creative_works', 'linked')
            .merge({ 'linked_creative_work' => @linked_objects }),
          partial_update: true,
          save_time: @timestamp
        )
      end

      test 'sanity check for updated_since' do
        assert_equal(6, DataCycleCore::Thing.where(things: { updated_at: @timestamp.. }).count)
        assert_equal(0, DataCycleCore::Thing.where('things.updated_at > ?', Time.zone.now).count)
        assert_equal(6, DataCycleCore::Filter::Search.new.updated_since(@timestamp - 1.minute).count)
        assert_equal(0, DataCycleCore::Filter::Search.new.updated_since(Time.zone.now).count)
      end

      test 'set updated_at at linked data and find main thing' do
        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Linked-Creative-Work-1').updated_since(@timestamp).count)
        new_timestamp = Time.zone.now
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Linked-Creative-Work-1').updated_since(new_timestamp).count)

        linked_item = DataCycleCore::Thing.find(@linked_objects.last)
        linked_item.updated_at = new_timestamp
        linked_item.save!

        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Linked-Creative-Work-1').updated_since(new_timestamp).count)
      end

      test 'set updated_at at linked data and find main thing then remove link --> do not find it again' do
        new_timestamp = Time.zone.now
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Linked-Creative-Work-1').updated_since(new_timestamp).count)

        linked_item = DataCycleCore::Thing.find(@linked_objects.last)
        linked_item.updated_at = new_timestamp
        linked_item.save!

        assert_equal(1, DataCycleCore::Filter::Search.new.template_names('Linked-Creative-Work-1').updated_since(new_timestamp).count)

        @data_set.set_data_hash(
          data_hash: { 'linked_creative_work' => @linked_objects[0..3] },
          partial_update: true,
          save_time: @timestamp
        )
        assert_equal(0, DataCycleCore::Filter::Search.new.template_names('Linked-Creative-Work-1').updated_since(new_timestamp).count)
      end
    end
  end
end
