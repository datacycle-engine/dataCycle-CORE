# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ScheduleTest < DataCycleCore::TestCases::ActiveSupportTestCase
    setup do
      @timeseries = DataCycleCore::TestPreparations.create_content(template_name: 'Timeseries', data_hash: { name: 'Series 1' })
    end

    test 'Timeseries callback to Thing' do
      updated_at = @timeseries.updated_at
      DataCycleCore::Timeseries.create(thing_id: @timeseries.id, property: 'series', timestamp: Time.zone.now, value: 1)
      assert(updated_at < @timeseries.reload.updated_at)
    end

    test 'Timeseries relation to Thing' do
      item = DataCycleCore::Timeseries.create(thing_id: @timeseries.id, property: 'series', timestamp: Time.zone.now, value: 1)
      assert_equal(@timeseries.id, item.thing.id)
    end

    test 'Thing relation to Timeseries' do
      item = DataCycleCore::Timeseries.create(thing_id: @timeseries.id, property: 'series', timestamp: Time.zone.now, value: 1)
      assert_equal(item.id, @timeseries.timeseries.first.id)
    end
  end
end
