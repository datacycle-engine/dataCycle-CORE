# frozen_string_literal: true

module DataCycleCore
  # geocodes a single Thing in the background (see Feature::AutoGeocode)
  class AutoGeocodeThingJob < UniqueApplicationJob
    PRIORITY = 12

    queue_as :default

    # job priority (lower runs earlier)
    def priority
      PRIORITY
    end

    # deduplicate queued jobs per content
    def delayed_reference_id
      arguments[0]
    end

    # geocode the given Thing if it still needs coordinates
    def perform(thing_id)
      return unless DataCycleCore::Feature::AutoGeocode.enabled?

      DataCycleCore::Thing.find_by(id: thing_id)&.auto_geocode!
    end
  end
end
