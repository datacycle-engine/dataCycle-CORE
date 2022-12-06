# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class TimeseriesTest < DataCycleCore::TestCases::ActiveSupportTestCase
    setup do
      @timeseries = DataCycleCore::TestPreparations.create_content(template_name: 'Timeseries', data_hash: { name: 'Series 1' })
    end

    def response
      {
        meta: {
          thing_id: @timeseries.id,
          processed: {
            inserted: 0,
            duplicates: 0
          }
        }
      }
    end

    def to_timeseries(s)
      { thing_id: @timeseries.id, property: s[0], timestamp: s[1], value: s[2] }
    end

    test 'Timeseries callback to Thing' do
      cache_valid_since = @timeseries.cache_valid_since
      updated_at = @timeseries.updated_at
      DataCycleCore::Timeseries.create(thing_id: @timeseries.id, property: 'series', timestamp: Time.zone.now, value: 1)
      assert(cache_valid_since < @timeseries.reload.cache_valid_since)
      assert_equal(updated_at, @timeseries.reload.updated_at)
    end

    test 'Timeseries relation to Thing' do
      item = DataCycleCore::Timeseries.create(thing_id: @timeseries.id, property: 'series', timestamp: Time.zone.now, value: 1)
      assert_equal(@timeseries.id, item.thing.id)
    end

    test 'Thing relation to Timeseries' do
      item = DataCycleCore::Timeseries.create(thing_id: @timeseries.id, property: 'series', timestamp: Time.zone.now, value: 1)
      assert_equal(item.id, @timeseries.timeseries.first.id)
    end

    test 'create multiple timeseries points' do
      data = []
      10.times { data.push(to_timeseries(['series', Time.zone.now, rand])) }

      result = DataCycleCore::Timeseries.create_all(@timeseries, data)
      expected = response
      expected[:meta][:processed][:inserted] = 10

      assert_equal(expected, result)
    end

    test 'create datapoints more than once' do
      data = []
      10.times { data.push(to_timeseries(['series', Time.zone.now, rand])) }

      DataCycleCore::Timeseries.create_all(@timeseries, data)
      result = DataCycleCore::Timeseries.create_all(@timeseries, data)
      expected = response
      expected[:meta][:processed][:duplicates] = 10

      assert_equal(expected, result)
    end

    test 'create datapoints with errors' do
      data = []
      10.times { data.push(to_timeseries(['series', nil, rand])) }

      result = DataCycleCore::Timeseries.create_all(@timeseries, data)

      assert result.key?(:error)
      assert result[:error].present?
    end
  end
end
