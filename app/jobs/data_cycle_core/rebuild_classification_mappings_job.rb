# frozen_string_literal: true

require 'rake'

module DataCycleCore
  class RebuildClassificationMappingsJob < UniqueApplicationJob
    PRIORITY = 0

    queue_as :default

    before_enqueue :broadcast_update

    def priority
      PRIORITY
    end

    def delayed_reference_id
      'DataCycleCore::Feature::TransitiveClassificationPath#rebuild_transitive_tables!'
    end

    def perform
      broadcast_update(rebuilding: true)
      DataCycleCore::Feature::TransitiveClassificationPath.rebuild_transitive_tables!
    ensure
      broadcast_update(rebuilding: false)
    end

    def self.broadcast_dashboard_jobs_now?
      true
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
