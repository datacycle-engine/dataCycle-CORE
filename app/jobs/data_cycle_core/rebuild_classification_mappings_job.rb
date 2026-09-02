# frozen_string_literal: true

module DataCycleCore
  # The one unique job that deliberately does not inherit UniqueApplicationJob: duplicates are dropped
  # by SolidQueue at dispatch time instead of before the enqueue. UniqueApplicationJob does it in a
  # +before_enqueue+, and a parent's callbacks run before a subclass's, so its +throw :abort+ would
  # preempt +broadcast_update+ below and leave the button unrefreshed for everyone watching the
  # dashboard — while a rebuild is in fact pending. The price is that +perform_later+ reports success
  # for a job that dispatch may then destroy; nothing reads its return value.
  class RebuildClassificationMappingsJob < ApplicationJob
    queue_as :default
    queue_with_priority 0
    limits_concurrency key: :rebuild_transitive_tables, on_conflict: :discard
    before_enqueue :broadcast_update

    def perform
      broadcast_update(rebuilding: true)
      DataCycleCore::Feature::TransitiveClassificationPath.rebuild_transitive_tables!
    ensure
      broadcast_update(rebuilding: false)
    end

    private

    def broadcast_update(rebuilding: true)
      TurboService.broadcast_localized_replace_to(
        'admin_dashboard_concept_mapping_job',
        partial: 'data_cycle_core/dash_board/concept_mappings_button',
        locals: { rebuilding: }
      )
    end
  end
end
