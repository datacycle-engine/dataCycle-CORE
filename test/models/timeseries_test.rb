# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class TimeseriesTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
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

      assert_operator(cache_valid_since, :<, @timeseries.reload.cache_valid_since)
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
      10.times { |i| data.push(to_timeseries(['series', Time.zone.now + i.seconds, rand])) }

      result = DataCycleCore::Timeseries.create_all(@timeseries, data)
      expected = response
      expected[:meta][:processed][:inserted] = 10

      assert_equal(expected, result)
    end

    test 'create datapoints more than once' do
      data = []
      10.times { |i| data.push(to_timeseries(['series', Time.zone.now + i.seconds, rand])) }

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
      assert_predicate result[:error], :present?
    end

    test 'create_all degrades to the same error hash for a bad timestamp on a collapsing property' do
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Timeseries', data_hash: { name: 'Collapse bad timestamp' })
      data = [{ thing_id: content.id, property: 'series_collapsed', timestamp: nil, value: 1 }]

      result = DataCycleCore::Timeseries.create_all(content, data)

      assert_equal({ error: 'wrong format for timestamps' }, result)
    end

    test 'create_all collapses repeated values within a single batch' do
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Timeseries', data_hash: { name: 'Collapse batch' })
      base = Time.zone.now
      data = [
        { thing_id: content.id, property: 'series_collapsed', timestamp: base, value: 1 },
        { thing_id: content.id, property: 'series_collapsed', timestamp: base + 1.minute, value: 1 },
        { thing_id: content.id, property: 'series_collapsed', timestamp: base + 2.minutes, value: 1 },
        { thing_id: content.id, property: 'series_collapsed', timestamp: base + 3.minutes, value: 2 }
      ]

      DataCycleCore::Timeseries.create_all(content, data)

      rows = DataCycleCore::Timeseries.where(thing_id: content.id, property: 'series_collapsed').order(:timestamp).to_a

      # run of 3 (value 1) collapses to start+end; trailing value 2 stays a single row
      assert_equal(3, rows.size)
      assert_equal([0, 3, 1], rows.map(&:redundant_count))
      assert_equal([1, 1, 2], rows.map(&:value))
      assert_equal(base.to_i, rows[0].timestamp.to_i)
      assert_equal((base + 2.minutes).to_i, rows[1].timestamp.to_i)
      assert_equal((base + 3.minutes).to_i, rows[2].timestamp.to_i)
    end

    test 'create_all collapses repeated values across separate calls' do
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Timeseries', data_hash: { name: 'Collapse across calls' })
      base = Time.zone.now

      DataCycleCore::Timeseries.create_all(content, [{ thing_id: content.id, property: 'series_collapsed', timestamp: base, value: 1 }])
      DataCycleCore::Timeseries.create_all(content, [{ thing_id: content.id, property: 'series_collapsed', timestamp: base + 1.minute, value: 1 }])
      DataCycleCore::Timeseries.create_all(content, [{ thing_id: content.id, property: 'series_collapsed', timestamp: base + 2.minutes, value: 1 }])

      rows = DataCycleCore::Timeseries.where(thing_id: content.id, property: 'series_collapsed').order(:timestamp).to_a

      assert_equal(2, rows.size)
      assert_equal(0, rows.first.redundant_count)
      assert_equal(3, rows.last.redundant_count)
      assert_equal((base + 2.minutes).to_i, rows.last.timestamp.to_i)
    end

    test 'create_all does not double count redelivered batches for collapsed values' do
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Timeseries', data_hash: { name: 'Collapse redelivery' })
      base = Time.zone.now
      data = [
        { thing_id: content.id, property: 'series_collapsed', timestamp: base, value: 1 },
        { thing_id: content.id, property: 'series_collapsed', timestamp: base + 1.minute, value: 1 }
      ]

      DataCycleCore::Timeseries.create_all(content, data)
      DataCycleCore::Timeseries.create_all(content, data)

      rows = DataCycleCore::Timeseries.where(thing_id: content.id, property: 'series_collapsed').order(:timestamp).to_a

      assert_equal(2, rows.size)
      assert_equal(2, rows.last.redundant_count)
    end
  end
end
