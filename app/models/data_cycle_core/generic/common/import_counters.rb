# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      # Single home for the per-content import outcome counters. Consumers (e.g. the Alloy adapter)
      # subscribe to these events and turn them into a metric labelled with the +result+ key below;
      # +rejected+ is reported per run by object_template_rejected.datacycle instead.
      module ImportCounters
        EVENTS = {
          success: 'object_import_succeeded.datacycle.counter',
          failure: 'object_import_failed.datacycle.counter',
          archived: 'object_import_archived.datacycle.counter',
          deleted: 'object_import_deleted.datacycle.counter'
        }.freeze

        # Publishes one outcome for one content; raises on a result without an event above.
        def self.instrument(result, utility_object:, template_name:)
          ActiveSupport::Notifications.instrument EVENTS.fetch(result), {
            external_system: utility_object.external_source,
            step_name: utility_object.step_name,
            template_name:
          }
        end
      end
    end
  end
end
