# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      # Auto-geocoding behaviour mixed into the Thing/DataHash lifecycle (prepended when the feature
      # is enabled). Everything here operates on the content itself (self), so the post-save hook and
      # the background job call instance methods instead of passing the content into the feature
      # class. Feature::AutoGeocode only resolves/validates configuration.
      #
      # The post-save hook (#after_save_data_hash), on each save:
      # * queues a background geocoding job when a watched address attribute changed and coordinates
      #   are needed; or
      # * when instead a previously auto-geocoded content had its coordinates cleared, synchronously
      #   drops the now-stale ownership tag - inline rather than via a job because it is a cheap local
      #   update with no external call, and so an editor's clear is respected immediately instead of
      #   re-geocoded. (The inline set_data_hash fires one extra update webhook for the changed
      #   classification, intended so downstream consumers see the tag change.)
      #
      # Re-entrancy / loop safety - neither write re-triggers the hook:
      # * #auto_geocode! writes only the geo target + latitude/longitude (+ optionally
      #   universal_classifications), none of which are watched address attribute_keys; and
      # * the stale-tag cleanup writes only universal_classifications, which is neither a watched
      #   address key (#queue_geocoding?) nor the geo target (#cleanup_stale_tag?).
      # UniqueApplicationJob dedup (one job per content id) is a further line of defence.
      module AutoGeocode
        extend ActiveSupport::Concern

        # queues geocoding on a relevant address change, else drops a now-stale ownership tag
        def after_save_data_hash(options)
          super

          return if embedded?
          return unless DataCycleCore::Feature::AutoGeocode.enabled?

          changed_keys = previous_datahash_changes&.keys

          if queue_geocoding?(changed_keys)
            DataCycleCore::AutoGeocodeThingJob.perform_later(id)
          elsif cleanup_stale_tag?(changed_keys)
            remove_auto_geocoded_tag
          end
        end

        # true when this save should enqueue geocoding: a watched address attribute changed, the
        # content is geocodable, and geocoding is actually needed (see #geocode_needed?). Checks the
        # cheap "did a watched key change?" first to short-circuit unrelated saves.
        def queue_geocoding?(changed_keys)
          return false unless DataCycleCore::Feature::AutoGeocode.attribute_keys.intersect?(Array.wrap(changed_keys))
          return false unless geocodable?

          geocode_needed?
        end

        # true when this save left the content carrying the auto-geocoded ownership tag but without
        # coordinates (e.g. an editor cleared them): the tag no longer reflects reality and must be
        # dropped (see #remove_auto_geocoded_tag). Gated on the geo target having actually changed in
        # this save (cheap) and on tagging being configured (otherwise ownership is untracked).
        def cleanup_stale_tag?(changed_keys)
          target = DataCycleCore::Feature::AutoGeocode.target_key
          return false unless Array.wrap(changed_keys).include?(target)
          return false if try(target).present?

          auto_geocoded?
        end

        # true when this content should be auto-geocoded; embedded contents never qualify.
        def geocodable?
          return false if try(:embedded?)

          DataCycleCore::Feature::AutoGeocode.allowed?(self)
        end

        # performs the geocoding (called from AutoGeocodeThingJob). Re-checks #geocodable? and
        # #geocode_needed? because the content may have changed between enqueue and execution.
        def auto_geocode!
          return false unless DataCycleCore::Feature['Geocode']&.enabled?
          return false unless geocodable?
          return false unless geocode_needed?

          address = auto_geocode_address_value
          return false if address.blank?

          location = I18n.with_locale(first_available_locale) do
            DataCycleCore::Feature['Geocode'].geocode_address(address)
          end
          return false unless location.is_a?(RGeo::Feature::Point) && location.present?

          set_data_hash(data_hash: auto_geocoded_data_hash(location), prevent_history: true)
        end

        # drops the auto-geocoded ownership tag (called when the coordinates we set were removed, see
        # #cleanup_stale_tag?). No-op when tagging is not configured or the tag is not present.
        def remove_auto_geocoded_tag
          tag_ids = DataCycleCore::Feature::AutoGeocode.geocoded_classification_ids
          return false if tag_ids.blank?

          current_ids = universal_classifications.pluck(:id)
          remaining = current_ids - tag_ids
          return false if remaining.size == current_ids.size

          set_data_hash(
            data_hash: { 'universal_classifications' => remaining },
            prevent_history: true
          )
        end

        private

        # coordinates should be (re-)derived when they are missing, or when the existing coordinates
        # were themselves set by auto-geocoding (see #auto_geocoded?). Coordinates from the source
        # system or an editor are authoritative and left untouched.
        def geocode_needed?
          return true if try(DataCycleCore::Feature::AutoGeocode.target_key).blank?

          auto_geocoded?
        end

        # true when this content currently carries the auto-geocoded tag, i.e. its coordinates were
        # set by this feature (and may therefore be refreshed). Requires tagging to be configured;
        # without it, ownership is unknown and existing coordinates are treated as authoritative.
        def auto_geocoded?
          tag_ids = DataCycleCore::Feature::AutoGeocode.geocoded_classification_ids
          return false if tag_ids.blank?

          universal_classifications.exists?(id: tag_ids)
        end

        # the (sufficient) address hash to geocode, nil otherwise
        def auto_geocode_address_value
          value = try(DataCycleCore::Feature::AutoGeocode.attribute_keys.first)
          value = value.to_h if value.respond_to?(:to_h)
          return if value.blank?
          return unless DataCycleCore::Feature::AutoGeocode.sufficient_address?(value)

          value
        end

        # data hash written back after geocoding: the resolved point + its longitude/latitude, plus
        # the auto-geocoded ownership tag when tagging is configured
        def auto_geocoded_data_hash(location)
          data = {
            DataCycleCore::Feature::AutoGeocode.target_key => location,
            DataCycleCore::Feature::AutoGeocode::LONGITUDE_KEY => location.x,
            DataCycleCore::Feature::AutoGeocode::LATITUDE_KEY => location.y
          }

          tag_ids = DataCycleCore::Feature::AutoGeocode.geocoded_classification_ids
          data['universal_classifications'] = (universal_classifications.pluck(:id) + tag_ids).uniq if tag_ids.present?

          data
        end
      end
    end
  end
end
