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
      'db:configure:rebuild_transitive_tables'
    end

    def perform
      Rake::Task.clear
      Rails.application.load_tasks

      broadcast_update(rebuilding: true)
      Rake::Task['db:configure:rebuild_transitive_tables'].invoke
      Rake::Task['db:configure:rebuild_transitive_tables'].reenable
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
