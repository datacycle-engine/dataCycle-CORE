# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class ScheduleTest < DataCycleCore::TestCases::ActiveSupportTestCase
        before(:all) do
          @event = DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: { name: 'Test Event Schedule Relation' })
          @other_event = DataCycleCore::TestPreparations.create_content(template_name: 'Event', data_hash: { name: 'Other Event' })
        end

        test 'set_schedule relation_name parameter has priority over relation from input_data' do
          schedule_hash = DataCycleCore::TestPreparations
            .generate_schedule(1.day.from_now.midday, 2.days.from_now.midday, 1.hour)
            .schedule_object
            .to_hash
            .with_indifferent_access
            .merge('relation' => 'some_other_relation')

          @event.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_hash] })

          schedules = DataCycleCore::Schedule.where(thing_id: @event.id)

          assert_equal 1, schedules.count
          assert_equal 'event_schedule', schedules.first.relation
          assert_equal 1, @event.load_schedule('event_schedule').count
          assert_equal 0, @event.load_schedule('some_other_relation').count
        end

        test 'set_schedule thing_id from content has priority over thing_id from input_data' do
          schedule_hash = DataCycleCore::TestPreparations
            .generate_schedule(1.day.from_now.midday, 2.days.from_now.midday, 1.hour)
            .schedule_object
            .to_hash
            .with_indifferent_access
            .merge('thing_id' => @other_event.id)

          @event.set_data_hash(partial_update: true, prevent_history: true, data_hash: { event_schedule: [schedule_hash] })

          assert_equal 1, DataCycleCore::Schedule.where(thing_id: @event.id).count
          assert_equal 0, DataCycleCore::Schedule.where(thing_id: @other_event.id).count
        end
      end
    end
  end
end
