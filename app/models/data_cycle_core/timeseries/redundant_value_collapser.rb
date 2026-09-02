# frozen_string_literal: true

module DataCycleCore
  class Timeseries
    # Redmine #39891: collapses runs of consecutive, identical timeseries values to
    # their first+last row (redundant_count tracks the run size), across separate writes.
    # Assumes append-only, roughly chronological ingestion per thing_id+property; a point
    # landing inside an already-collapsed range (out-of-order/late) is not specially merged.
    class RedundantValueCollapser
      # raised for a nil/blank/unparseable/wrong-type timestamp; rescued by Timeseries.create_all
      class InvalidTimestampError < StandardError
        def initialize(msg = 'wrong format for timestamps')
          super
        end
      end

      # backfills historical rows; unlike #call, start/end already exist, we just delete the interior
      def self.backfill!(thing_id:, property:, dry_run: false)
        deleted = 0

        Timeseries.transaction do
          # without this, a concurrent live write (#call) for the same thing_id+property
          # could read/write mid-backfill and end up racing with it - see #call's lock!
          lock!(thing_id, property)

          scope = Timeseries.where(thing_id:, property:)
          points = scope.order(:timestamp).pluck(:timestamp, :value).map { |timestamp, value| { timestamp:, value: } }

          group_into_runs(points).each do |run|
            next if run[:points].size <= 1

            first_timestamp = run[:points].first[:timestamp]
            last_timestamp = run[:points].last[:timestamp]
            interior_count = run[:points].size - 2

            unless dry_run
              # a range condition, not an IN-list of every interior timestamp, so a
              # run of thousands of raw points doesn't blow up the delete statement
              scope.where('timestamp > ? AND timestamp < ?', first_timestamp, last_timestamp).delete_all if interior_count.positive?
              # start's count moves to 0: the end row's count (below) already covers the whole run
              scope.where(timestamp: first_timestamp).update_all(redundant_count: 0)
              scope.where(timestamp: last_timestamp).update_all(redundant_count: run[:points].size)
            end

            deleted += interior_count
          end

          raise ActiveRecord::Rollback if dry_run
        end

        { deleted: }
      end

      # serializes writers per thing_id+property; row locks alone can't guard a row that doesn't exist yet
      def self.lock!(thing_id, property)
        Timeseries.connection.execute(
          Timeseries.sanitize_sql_array(['SELECT pg_advisory_xact_lock(hashtext(?), hashtext(?))', thing_id.to_s, property.to_s])
        )
      end

      # groups consecutive points with an identical value into { value:, points: [...] } runs
      def self.group_into_runs(points)
        points.each_with_object([]) do |point, runs|
          if runs.last && runs.last[:value] == point[:value]
            runs.last[:points] << point
          else
            runs << { value: point[:value], points: [point] }
          end
        end
      end

      def initialize(thing_id:, property:)
        @thing_id = thing_id
        @property = property
      end

      # points: [{ timestamp:, value: }, ...], unsorted; returns { inserted:, updated: }
      def call(points)
        return { inserted: 0, updated: 0 } if points.blank?

        # timestamp/value may arrive as raw Strings (e.g. the v4 webhook's parsed JSON/CSV
        # body is never cast) - normalize both before comparing or storing. .floor(6) also
        # matches timestamptz's precision, or a value read back from the DB falsely compares
        # as earlier than the same instant still held in memory at full precision
        points = points.map { |point| { timestamp: normalize_timestamp(point[:timestamp]), value: point[:value].to_f } }
        runs = self.class.group_into_runs(points.sort_by { |point| point[:timestamp] })
        inserted = 0
        updated = 0

        # requires_new: even when #call runs inside an already-open save transaction (the
        # set_data_hash path), a failure here rolls back to this savepoint instead of
        # poisoning the whole outer transaction
        Timeseries.transaction(joinable: false, requires_new: true) do
          lock!

          existing_timestamp, existing_value, existing_redundant_count = scope
            .order(timestamp: :desc)
            .limit(1)
            .pick(:timestamp, :value, :redundant_count)

          if existing_value == runs.first[:value]
            merged = merge_into_existing_run(runs.shift, existing_timestamp:, existing_redundant_count:)
            inserted += merged[:inserted]
            updated += merged[:updated]
          end

          rows = runs.flat_map { |run| run_to_rows(run) }
          inserted += Timeseries.insert_all(rows, unique_by: :thing_attribute_timestamp_idx, returning: :thing_id).count if rows.present?
        end

        { inserted:, updated: }
      end

      private

      def scope
        Timeseries.where(thing_id: @thing_id, property: @property)
      end

      def lock!
        self.class.lock!(@thing_id, @property)
      end

      # nil/blank/unparseable/wrong-type (e.g. an epoch Integer) timestamps must fail the
      # same way the plain (non-collapsing) insert path already does - a NOT NULL
      # violation, rescued by create_all into { error: 'wrong format for timestamps' } -
      # instead of a raw NoMethodError/500. #try(:in_time_zone) returns nil for anything
      # that doesn't respond to it (nil, an Integer, ...) instead of raising, and - unlike
      # DataConverter.string_to_datetime's `change(usec: 0)` - keeps sub-second precision
      # for a String the same way it's already kept for a Time/TimeWithZone.
      def normalize_timestamp(raw)
        timestamp = raw.try(:in_time_zone)&.floor(6)
        raise InvalidTimestampError if timestamp.nil?

        timestamp
      rescue ArgumentError
        raise InvalidTimestampError
      end

      # extends the existing run with any of the incoming run's points newer than it;
      # returns zeroes if they all turn out to be an already-applied retry
      def merge_into_existing_run(run, existing_timestamp:, existing_redundant_count:)
        new_points = run[:points].select { |point| point[:timestamp] > existing_timestamp }
        return { inserted: 0, updated: 0 } if new_points.blank?

        merged_count = existing_redundant_count + new_points.size
        new_timestamp = new_points.last[:timestamp]

        if existing_redundant_count > 1
          scope.where(timestamp: existing_timestamp).update_all(timestamp: new_timestamp, redundant_count: merged_count)
          { inserted: 0, updated: 1 }
        else
          # the existing row was a lone, unrepeated point; it becomes this run's start
          # marker, so its own count moves to 0 - the new end row now accounts for both
          scope.where(timestamp: existing_timestamp).update_all(redundant_count: 0)
          Timeseries.insert_all(
            [{ thing_id: @thing_id, property: @property, timestamp: new_timestamp, value: run[:value], redundant_count: merged_count }],
            unique_by: :thing_attribute_timestamp_idx
          )
          { inserted: 1, updated: 1 }
        end
      end

      def run_to_rows(run)
        base = { thing_id: @thing_id, property: @property, value: run[:value] }

        return [base.merge(timestamp: run[:points].first[:timestamp], redundant_count: 1)] if run[:points].size == 1

        [
          # start's count is 0, not 1: the end row's count already covers the whole run
          base.merge(timestamp: run[:points].first[:timestamp], redundant_count: 0),
          base.merge(timestamp: run[:points].last[:timestamp], redundant_count: run[:points].size)
        ]
      end
    end
  end
end
