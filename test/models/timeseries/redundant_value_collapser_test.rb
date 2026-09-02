# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  class Timeseries
    class RedundantValueCollapserTest < DataCycleCore::TestCases::ActiveSupportTestCase
      setup do
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Timeseries', data_hash: { name: 'Collapser Series' })
      end

      def collapser
        RedundantValueCollapser.new(thing_id: @content.id, property: 'series_collapsed')
      end

      def rows
        DataCycleCore::Timeseries.where(thing_id: @content.id, property: 'series_collapsed').order(:timestamp)
      end

      test 'a single, unrepeated value stays a single row' do
        collapser.call([{ timestamp: Time.zone.now, value: 1 }])

        assert_equal 1, rows.size
        assert_equal 1, rows.first.redundant_count
      end

      test 'a repeated value collapses to exactly two rows' do
        base = Time.zone.now

        collapser.call([{ timestamp: base, value: 1 }])
        collapser.call([{ timestamp: base + 1.minute, value: 1 }])

        assert_equal 2, rows.size
        assert_equal 0, rows.first.redundant_count
        assert_equal 2, rows.last.redundant_count
        assert_equal (base + 1.minute).to_i, rows.last.timestamp.to_i
      end

      test 'a further repeat extends the existing end marker instead of adding a third row' do
        base = Time.zone.now

        collapser.call([{ timestamp: base, value: 1 }])
        collapser.call([{ timestamp: base + 1.minute, value: 1 }])
        collapser.call([{ timestamp: base + 2.minutes, value: 1 }])

        assert_equal 2, rows.size
        assert_equal 3, rows.last.redundant_count
        assert_equal (base + 2.minutes).to_i, rows.last.timestamp.to_i
      end

      test 'a different value starts a new run' do
        base = Time.zone.now

        collapser.call([{ timestamp: base, value: 1 }])
        collapser.call([{ timestamp: base + 1.minute, value: 1 }])
        collapser.call([{ timestamp: base + 2.minutes, value: 2 }])

        assert_equal 3, rows.size
        assert_equal [0, 2, 1], rows.map(&:redundant_count)
        assert_equal [1, 1, 2], rows.map(&:value)
      end

      test 'redelivering the same batch does not inflate redundant_count' do
        base = Time.zone.now
        points = [{ timestamp: base, value: 1 }, { timestamp: base + 1.minute, value: 1 }]

        collapser.call(points)
        collapser.call(points)

        assert_equal 2, rows.size
        assert_equal 2, rows.last.redundant_count
      end

      test 'call returns inserted/updated counts' do
        base = Time.zone.now

        result = collapser.call([{ timestamp: base, value: 1 }])

        assert_equal({ inserted: 1, updated: 0 }, result)

        result = collapser.call([{ timestamp: base + 1.minute, value: 1 }])

        # inserts the new end marker AND updates the old singleton's count to 0
        assert_equal({ inserted: 1, updated: 1 }, result)

        result = collapser.call([{ timestamp: base + 2.minutes, value: 1 }])

        assert_equal({ inserted: 0, updated: 1 }, result)
      end

      test 'call with blank points is a no-op' do
        result = collapser.call([])

        assert_equal({ inserted: 0, updated: 0 }, result)
        assert_equal 0, rows.size
      end

      test 'call accepts string timestamps and values, as delivered by the v4 webhook/CSV' do
        base = Time.zone.now

        collapser.call([{ timestamp: base.iso8601, value: '1' }])
        collapser.call([{ timestamp: (base + 1.minute).iso8601, value: '1' }])
        collapser.call([{ timestamp: (base + 2.minutes).iso8601, value: '2' }])

        assert_equal 3, rows.size
        assert_equal [0, 2, 1], rows.map(&:redundant_count)
        assert_equal [1, 1, 2], rows.map(&:value)
      end

      test 'call preserves sub-second precision for a string timestamp, same as for a Time' do
        collapser.call([{ timestamp: '2026-04-30T12:00:00.123456Z', value: 1 }])

        assert_equal 123_456, rows.first.timestamp.usec
      end

      test 'call raises InvalidTimestampError instead of crashing on a nil, blank, unparseable, or wrong-type timestamp' do
        [nil, '', '   ', 'not-a-date', 1_735_689_600].each do |bad_timestamp|
          error = assert_raises(RedundantValueCollapser::InvalidTimestampError) do
            collapser.call([{ timestamp: bad_timestamp, value: 1 }])
          end
          assert_equal 'wrong format for timestamps', error.message
        end

        assert_equal 0, rows.size
      end

      test 'a same-value point landing inside an already-collapsed range is not merged in (documented limitation)' do
        base = Time.zone.now

        collapser.call([{ timestamp: base, value: 1 }])
        collapser.call([{ timestamp: base + 2.minutes, value: 1 }])
        # late-arriving point for a timestamp inside the now-collapsed [base, base + 2.minutes] range
        result = collapser.call([{ timestamp: base + 1.minute, value: 1 }])

        assert_equal({ inserted: 0, updated: 0 }, result)
        assert_equal 2, rows.size
        assert_equal 2, rows.last.redundant_count
      end

      def insert_raw(*value_by_offset_minutes)
        data = value_by_offset_minutes.map do |offset, value|
          { thing_id: @content.id, property: 'series_collapsed', timestamp: Time.zone.now + offset.minutes, value: }
        end

        DataCycleCore::Timeseries.insert_all(data, unique_by: :thing_attribute_timestamp_idx)
      end

      test 'backfill! collapses a historical run down to start + end, deletes the interior' do
        insert_raw([0, 1], [1, 1], [2, 1], [3, 1])

        result = RedundantValueCollapser.backfill!(thing_id: @content.id, property: 'series_collapsed')

        assert_equal({ deleted: 2 }, result)
        assert_equal 2, rows.size
        assert_equal [0, 4], rows.map(&:redundant_count)
        assert_equal [1, 1], rows.map(&:value)
      end

      test 'backfill! leaves unrepeated singleton rows untouched' do
        insert_raw([0, 1], [1, 2], [2, 3])

        result = RedundantValueCollapser.backfill!(thing_id: @content.id, property: 'series_collapsed')

        assert_equal({ deleted: 0 }, result)
        assert_equal 3, rows.size
        assert_equal [1, 1, 1], rows.map(&:redundant_count)
      end

      test 'backfill! handles multiple separate historical runs independently' do
        # run of 3, a singleton, and a run of exactly 2 (no interior, but rc still 1 -> 2)
        insert_raw([0, 1], [1, 1], [2, 1], [3, 2], [4, 3], [5, 3])

        result = RedundantValueCollapser.backfill!(thing_id: @content.id, property: 'series_collapsed')

        assert_equal({ deleted: 1 }, result)
        assert_equal 5, rows.size
        assert_equal [1, 1, 2, 3, 3], rows.map(&:value)
        assert_equal [0, 3, 1, 0, 2], rows.map(&:redundant_count)
      end

      test 'backfill! with dry_run true makes no changes but reports what would be deleted' do
        insert_raw([0, 1], [1, 1], [2, 1])

        result = RedundantValueCollapser.backfill!(thing_id: @content.id, property: 'series_collapsed', dry_run: true)

        assert_equal({ deleted: 1 }, result)
        assert_equal 3, rows.size
        assert_equal [1, 1, 1], rows.map(&:redundant_count)
      end

      test 'backfill! takes the same advisory lock as #call, to serialize against concurrent writes' do
        insert_raw([0, 1], [1, 1])
        locked_with = nil

        RedundantValueCollapser.stub(:lock!, ->(thing_id, property) { locked_with = [thing_id, property] }) do
          RedundantValueCollapser.backfill!(thing_id: @content.id, property: 'series_collapsed')
        end

        assert_equal [@content.id, 'series_collapsed'], locked_with
      end
    end
  end
end
