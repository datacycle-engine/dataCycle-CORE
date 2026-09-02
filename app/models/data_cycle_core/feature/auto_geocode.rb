# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Automatically geocodes content (POIs, gastronomy, ...) based on its address.
    #
    # This feature is similar to the Geocode_functions transformation,
    # but it is applied automatically after the content is saved,
    # rather than as a transformation step.
    # It may in future replace the Geocode_functions transformation; for now, both are available.
    #
    # Enabled per data-definition via the feature configuration. A post-save hook
    # (DataHash::AutoGeocode) detects changes to the address attribute and queues an
    # AutoGeocodeThingJob. The job reuses the existing 'Geocode' feature (Toursprung)
    # to translate the address into coordinates and writes them back.
    #
    # This class only resolves configuration and validates it; the actual behaviour
    # (deciding whether to geocode, performing it, tagging) lives as instance methods on the
    # content itself, mixed in via DataHash::AutoGeocode (see #data_hash_module). That keeps the
    # logic where the data is and avoids passing the content around as an argument.
    #
    # Which templates are auto-geocoded is decided per-template, like :creatable: / :geocode:: a
    # template opts in via its data definition (:features: :auto_geocode: :allowed: true), which the
    # framework merges into Feature::Base#allowed?(content). The global :allowed: defaults to false
    # (opt-in). #allowed? is narrowed below to templates that actually carry the address attribute +
    # geo target, so a template that inherits the opt-in from an ancestor (e.g. any Place subtype
    # inherits Place's) without those properties is simply inert rather than a misconfiguration.
    #
    # The watched address attribute(s) and the geo target default to the geocode feature's
    # :attribute_keys / :target_key ('address' -> 'location', the schema.org postal-address -> geo
    # mapping from datacycle-schema-base's 'postal_address' + 'geo' mixins); setting :attribute_keys /
    # :target_key on :auto_geocode: itself is optional and only needed to override them. latitude/
    # longitude are derived from the resolved point.
    class AutoGeocode < Base
      LATITUDE_KEY = 'latitude'
      LONGITUDE_KEY = 'longitude'
      GEOCODING_TREE = 'Geocoding'
      GEOCODED_ALIAS = 'geocoded'
      # address sub-fields required for a meaningful geocoding request
      REQUIRED_ADDRESS_KEYS = ['street_address', 'postal_code', 'address_locality'].freeze

      class << self
        # post-save hook (and the geocoding behaviour) prepended into the content lifecycle
        def data_hash_module
          DataCycleCore::Feature::DataHash::AutoGeocode
        end

        # property names of the address attribute(s) to watch for changes (the address source)
        def attribute_keys(content = nil)
          geocode_feature = DataCycleCore::Feature['Geocode']

          configuration(content)['attribute_keys'] || geocode_feature&.attribute_keys(content) || []
        end

        # property the resolved geo point is written to (the geo target), from :target_key config
        def target_key(content = nil)
          geocode_feature = DataCycleCore::Feature['Geocode']

          configuration(content)['target_key'] || geocode_feature&.target_key(content)
        end

        # classification ids for the hard-coded Geocoding/geocoded ownership tag. Used by the
        # content to apply, check and drop the tag.
        def geocoded_classification_ids
          DataCycleCore::Concept.for_tree(GEOCODING_TREE).with_internal_name(GEOCODED_ALIAS).pluck(:classification_id)
        end

        # true when the address hash can yield a *meaningful* position, i.e. one precise enough to be
        # worth storing. Requires the street-level sub-fields AND a house number in the street address.
        #
        # Rationale (#45442, customer decision 2026-07-27): coordinates must stay empty when no correct
        # position can be computed - no town/village/country centroid fallbacks, because "scheinbar
        # korrekte, aber ungenaue" coordinates hide which contents actually lack a usable geocoding.
        # Without a street the geocoder answers with the locality centroid; without a house number with
        # the street centroid. The house-number heuristic is the geocode feature's, the same rule
        # dc:geocode:check_address_divergence uses for a "precise address" (#35020) - delegated rather
        # than duplicated, and nil-safe because the geocode provider is an optional plugin gem.
        #
        # @param address [Hash] the address sub-field hash
        # @return [Boolean]
        def sufficient_address?(address)
          REQUIRED_ADDRESS_KEYS.all? { |key| address[key].present? } &&
            DataCycleCore::Feature['Geocode']&.street_address_with_house_number?(address['street_address']).present?
        end

        # names of the templates that opt into auto-geocoding (and can carry coordinates, see #allowed?)
        #
        # @return [Array<String>]
        def allowed_template_names
          DataCycleCore::ThingTemplate.all.filter_map do |thing_template|
            thing_template.template_name if allowed?(DataCycleCore::Thing.new(thing_template:))
          end
        end

        # every content whose template opts into auto-geocoding. The default scope of the backfill
        # (dc:geocode:auto_geocode and the one-time data migration); whether an individual content
        # actually needs geocoding is its own decision (Thing#auto_geocode_needed?).
        #
        # @return [ActiveRecord::Relation]
        def auto_geocodable_things
          DataCycleCore::Thing.where(template_name: allowed_template_names)
        end

        # Backfills auto-geocoding over a set of contents: enqueues a job for each content that needs
        # geocoding and counts the rest by reason, so content that deliberately keeps empty coordinates
        # is reported rather than silently skipped. Shared by dc:geocode:auto_geocode and the one-time
        # backfill data migration. A single content raising must not abort the batch - EXCEPT for
        # database errors, see below.
        #
        # @param contents [ActiveRecord::Relation] the contents to check
        # @param dry_run [Boolean] only count, enqueue nothing
        # @param logger [Logger] receives one line per failed content, defaults to Rails.logger so a
        #   swallowed error is never invisible (the data migration passes none)
        # @yield after every content, for progress reporting
        # @return [Hash{Symbol => Integer}] counts per Thing#auto_geocode_status, plus :errors and
        #   :enqueued (the subset of :needed that reached the queue, see below)
        def backfill(contents, dry_run: false, logger: Rails.logger, &progress)
          stats = Hash.new(0)

          contents.find_each do |content|
            status = content.auto_geocode_status

            # AutoGeocodeThingJob is a UniqueApplicationJob: an enqueue for a content that already has
            # a duplicate waiting is aborted and answers false. Counting :needed as "enqueued" would
            # report work that was never queued, so count what the queue actually took.
            enqueued = DataCycleCore::AutoGeocodeThingJob.perform_later(content.id) if status == :needed && !dry_run
            stats[:enqueued] += 1 if enqueued

            # counted last so a content that raised is only counted as an error, never twice
            stats[status] += 1
          rescue ActiveRecord::ActiveRecordError
            # A failed statement leaves the surrounding transaction unusable (this also runs from a data
            # migration), so continuing would make every later query fail with PG::InFailedSqlTransaction
            # and bury the actual cause. Fail loudly on the real error instead.
            raise
          rescue StandardError => e
            stats[:errors] += 1
            logger&.error("[AutoGeocode backfill] id: #{content.id} - #{e.class}: #{e.message}")
          ensure
            progress&.call
          end

          stats
        end

        # one-line, human-readable summary of #backfill's counts (for the task output and the
        # migration's `say`)
        #
        # @param stats [Hash{Symbol => Integer}] as returned by #backfill
        # @param dry_run [Boolean] phrases the enqueued count as hypothetical
        # @return [String]
        def backfill_summary(stats, dry_run: false)
          # :enqueued is the subset of :needed that reached the queue, not a status of its own, so it
          # must not count towards the contents checked. A dry run enqueues nothing and cannot know
          # which ones would be dropped as duplicates, so there :needed is all there is to report.
          enqueued = dry_run ? stats[:needed] : stats[:enqueued]
          duplicates = stats[:needed] - enqueued

          summary = "#{stats.except(:enqueued).values.sum} contents checked: #{enqueued} #{dry_run ? 'would be enqueued' : 'enqueued'}, " \
                    "#{stats[:has_coordinates]} already have coordinates, #{stats[:refreshable]} already auto-geocoded, " \
                    "#{stats[:no_address]} without address, #{stats[:insufficient_address]} with insufficient address, " \
                    "#{stats[:not_allowed]} not auto-geocodable, #{stats[:errors]} errors."

          duplicates.positive? ? "#{summary} #{duplicates} already had a job queued." : summary
        end

        # auto_geocode is allowed for a content only when it both opts in (super: globally enabled +
        # the template's :features: :auto_geocode: :allowed: true, possibly inherited from an
        # ancestor) AND its template actually carries the watched address attribute(s) + geo target.
        #
        # The attribute check makes an inherited opt-in on a non-geocodable template (e.g. a Place
        # subtype without an address) inert instead of an error.
        def allowed?(content = nil)
          return false unless super

          property_names = Array(content.try(:property_names))
          attribute_keys(content).intersect?(property_names) && property_names.include?(target_key(content))
        end
      end
    end
  end
end
