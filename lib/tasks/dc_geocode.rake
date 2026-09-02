# frozen_string_literal: true

namespace :dc do
  namespace :geocode do
    # Backfills auto-geocoding for content the post-save hook never saw (see Feature::AutoGeocode):
    # the hook only fires when a watched address attribute *changed*, and re-imports diff against the
    # stored values, so content imported before the feature was enabled - or before its template opted
    # in - never receives coordinates, not even on a full/reset re-import.
    #
    # Contents are selected via a StoredFilter- or WatchList id/slug, so the scope is a parameter (same
    # pattern as dc:cache:warm_up_geocoder and dc:geocode:check_address_divergence). Without an endpoint
    # the scope is every content whose template opts into :auto_geocode:.
    #
    # Only content that actually needs geocoding is enqueued (Thing#auto_geocode_needed?). Everything
    # else is counted by reason (Thing#auto_geocode_status), so content that deliberately stays without
    # coordinates - insufficient address data, per the customer decision in #45442 - shows up in the
    # summary instead of being silently skipped. `dry_run` reports those buckets and enqueues nothing,
    # which also answers "why did this content not get coordinates?" on a running instance.
    #
    #   dc:geocode:auto_geocode[endpoint_id_or_slug,dry_run]
    desc 'enqueue auto-geocoding for contents that still need coordinates'
    task :auto_geocode, [:endpoint_id_or_slug, :dry_run] => :environment do |_, args|
      abort('feature disabled!') unless DataCycleCore::Feature::AutoGeocode.enabled?

      dry_run = args.dry_run.to_s == 'true'
      contents = DataCycleCore::Feature::AutoGeocode.auto_geocodable_things

      if args.endpoint_id_or_slug.present?
        stored_filter = DataCycleCore::StoredFilter.by_id_or_slug(args.endpoint_id_or_slug).first
        watch_list = DataCycleCore::WatchList.without_my_selection.by_id_or_slug(args.endpoint_id_or_slug).first if stored_filter.nil?
        abort('endpoint not found!') if stored_filter.nil? && watch_list.nil?

        contents = stored_filter.nil? ? watch_list.things : stored_filter.apply.query
      end

      logger = Logger.new('log/auto_geocode.log')
      logger.info("Started auto-geocoding backfill (endpoint: #{args.endpoint_id_or_slug.presence || 'all opted-in templates'}, dry_run: #{dry_run})...")

      progressbar = ProgressBar.create(total: contents.size, format: '%t |%w>%i| %a - %c/%C', title: 'Auto-Geocode Backfill')

      stats = DataCycleCore::Feature::AutoGeocode.backfill(contents, dry_run:, logger:) { progressbar.increment }
      summary = DataCycleCore::Feature::AutoGeocode.backfill_summary(stats, dry_run:)

      logger.info("[DONE] #{summary}")
      puts summary
    end
  end
end
