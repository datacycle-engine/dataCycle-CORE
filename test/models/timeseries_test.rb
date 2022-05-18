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
          property: 'series',
          processed: {
            inserted: 0,
            duplicates: 0,
            errors: 0
          }
        }
      }
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

    test 'Timeseries::Status' do
      DataCycleCore::Timeseries::Status.types.each do |type|
        status = DataCycleCore::Timeseries::Status.new
        msg = 'test'
        status.send(type, msg)
        assert_equal(true, status.send("#{type}?"))
        assert_equal(msg, status.send("#{type}s").first)
        assert_equal(msg, status.status_hash[type.to_sym].first)
      end

      type = DataCycleCore::Timeseries::Status.types.first
      status = DataCycleCore::Timeseries::Status.new
      msg = 'test'
      5.times.each { status.send(type, msg) }
      assert_equal(5, status.send("#{type}s").size)
    end

    test 'create multiple timeseries points' do
      data = []
      10.times { data.push([Time.zone.now, rand]) }

      status = DataCycleCore::Timeseries.create_all(@timeseries, 'series', data)
      expected = response
      expected[:meta][:processed][:inserted] = 10

      assert_equal(expected, status)
    end

    test 'create datapoints more than once' do
      data = []
      10.times { data.push([Time.zone.now, rand]) }

      DataCycleCore::Timeseries.create_all(@timeseries, 'series', data)
      status = DataCycleCore::Timeseries.create_all(@timeseries, 'series', data)
      expected = response
      expected[:meta][:processed][:duplicates] = 10

      assert_equal(expected, status)
    end

    test 'create datapoints with errors' do
      data = []
      10.times { data.push([nil, rand]) }

      status = DataCycleCore::Timeseries.create_all(@timeseries, 'series', data)
      expected = response
      expected[:meta][:processed][:errors] = 10

      assert_equal(expected, status.except(:error))
      assert_equal(10, status[:error].size)
    end
  end
end
