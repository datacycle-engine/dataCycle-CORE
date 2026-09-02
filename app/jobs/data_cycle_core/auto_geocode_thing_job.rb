# frozen_string_literal: true

module DataCycleCore
  # geocodes a single Thing in the background (see Feature::AutoGeocode)
  class AutoGeocodeThingJob < UniqueApplicationJob
    PRIORITY = 12

    queue_as :default
    # job priority (lower runs earlier); must not override the +priority+ reader, otherwise
    # ActiveJob cannot bump it between retries (see JobExtensions::Callbacks)
    queue_with_priority PRIORITY
    # deduplicate queued jobs per content, which is what UniqueApplicationJob keys its
    # abort_if_queued check on
    limits_concurrency key: ->(*args) { args[0] }

    # geocode the given Thing if it still needs coordinates
    def perform(thing_id)
      return unless DataCycleCore::Feature::AutoGeocode.enabled?

      DataCycleCore::Thing.find_by(id: thing_id)&.auto_geocode!
    end
  end
end
