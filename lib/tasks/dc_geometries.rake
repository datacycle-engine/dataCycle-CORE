# frozen_string_literal: true

namespace :dc do
  namespace :geometries do
    # Removes consecutive duplicate points from the geometries of a collection's contents.
    #
    # Imported tracks routinely carry repeated points - GPS pauses and standstills record the same
    # coordinate several times. They are invisible as long as the points stay on top of each other,
    # but any per-vertex transformation (randomization, snapping, offsetting) turns each duplicate
    # into an independent point and the track starts to zigzag. Removing them beforehand is what
    # keeps such a transformation from producing noise.
    #
    # Writes straight to the geometries table via ST_RemoveRepeatedPoints instead of going through
    # set_data_hash: within the permitted tolerance the cleanup leaves the 2D shape untouched, and a
    # set_data_hash over every content of a large collection would drag history, webhooks, search
    # index and cache invalidation along for it. The trade-off is that exactly those do NOT run -
    # callers who need the search index or downstream caches refreshed have to trigger that
    # separately. geom_simple is a generated column and updates itself.
    #
    # Above tolerance 0 the comparison is XY-only, so a point sharing XY with a differing Z collapses
    # and that Z goes with it. On stationary altimeter jitter that is a correction rather than a
    # loss, but it does move 3D length and ascent slightly - only the 2D shape stays identical.
    #
    #   dc:geometries:remove_repeated_points[endpoint_id_or_slug,tolerance,dry_run]
    desc 'remove consecutive duplicate points from the geometries of a collection'
    task :remove_repeated_points, [:endpoint_id_or_slug, :tolerance, :dry_run] => :environment do |_, args|
      # 1e-9 degrees is roughly 0.1 mm - far below the resolution of any real track point, but large
      # enough to catch duplicates that share XY and differ only in Z: at tolerance 0
      # ST_RemoveRepeatedPoints compares every dimension and keeps those.
      default_tolerance = 0.000000001
      # ~11 cm. Past that the function stops dropping duplicates and starts reshaping tracks, and
      # this task writes without a history entry to restore from.
      max_tolerance = 0.000001

      abort('ERROR: no endpoint provided') if args.endpoint_id_or_slug.blank?

      raw_tolerance = args.tolerance.presence
      tolerance = raw_tolerance.nil? ? default_tolerance : Float(raw_tolerance, exception: false)
      abort("ERROR: tolerance is not a number: #{raw_tolerance}") if tolerance.nil?
      abort("ERROR: tolerance has to be between 0 and #{max_tolerance}") unless tolerance.between?(0, max_tolerance)

      dry_run = args.dry_run.to_s == 'true'

      collection = DataCycleCore::Collection.by_id_or_slug(args.endpoint_id_or_slug).first
      abort('ERROR: endpoint not found!') if collection.nil?

      puts '###### DRY-RUN: no database changes will be made' if dry_run

      logger = Logger.new('log/remove_repeated_points.log')
      logger.info("Started removing repeated points (endpoint: #{args.endpoint_id_or_slug}, tolerance: #{tolerance}, dry_run: #{dry_run})...")

      # One statement instead of a read plus a write against the ids it returned: no row can change
      # between deciding and writing, and there is no id list to carry. The duplicate check sits in
      # candidates so only the rows actually rewritten keep their cleaned geometry - materializing it
      # for the whole collection spills it to disk and makes the run scale with collection size
      # rather than with the number of duplicates. ST_IsValid keeps a geometry that cleans up
      # invalid - reachable with polygons - from failing check_geom_simple_validity and taking every
      # other geometry's cleanup down with it.
      cte = <<~SQL.squish
        WITH candidates AS MATERIALIZED (
          SELECT geometries.id,
            geometries.thing_id,
            ST_NPoints(geometries.geom) AS points_before,
            ST_RemoveRepeatedPoints(geometries.geom, #{tolerance}) AS cleaned
          FROM geometries
          WHERE geometries.thing_id IN (#{collection.things_nested.select(:id).to_sql})
            AND ST_NPoints(ST_RemoveRepeatedPoints(geometries.geom, #{tolerance})) < ST_NPoints(geometries.geom)
        ), targets AS (
          SELECT candidates.*
          FROM candidates
          WHERE ST_IsValid(candidates.cleaned)
        )
      SQL

      affected = ActiveRecord::Base.transaction(joinable: false, requires_new: true) do
        ActiveRecord::Base.connection.exec_query('SET LOCAL statement_timeout = 0;')

        sql = if dry_run
                "#{cte} SELECT targets.id, targets.thing_id, targets.points_before, ST_NPoints(targets.cleaned) AS points_after FROM targets"
              else
                "#{cte} UPDATE geometries SET geom = targets.cleaned FROM targets WHERE geometries.id = targets.id " \
                  'RETURNING geometries.id, targets.thing_id, targets.points_before, ST_NPoints(geometries.geom) AS points_after'
              end

        ActiveRecord::Base.connection.select_all(sql).to_a
      end

      removed = affected.sum { |r| r['points_before'] - r['points_after'] }

      # one line per geometry: this task bypasses set_data_hash, so nothing else records what was
      # touched - without it there is no way to tell afterwards which contents were modified.
      affected.each do |row|
        logger.info("thing #{row['thing_id']} / geometry #{row['id']}: #{row['points_before']} -> #{row['points_after']} points (-#{row['points_before'] - row['points_after']})")
      end

      summary = "#{removed} duplicate point(s) #{dry_run ? 'would be' : 'were'} removed from #{affected.size} geometr#{affected.size == 1 ? 'y' : 'ies'} (tolerance: #{tolerance})"
      logger.info("[DONE] #{summary}")
      puts "done: #{summary}"
    end
  end
end
