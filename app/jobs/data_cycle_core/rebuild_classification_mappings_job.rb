# frozen_string_literal: true

require 'rake'

module DataCycleCore
  class RebuildClassificationMappingsJob < UniqueApplicationJob
    PRIORITY = 0

    REFERENCE_TYPE = 'rebuild_classification_mappings'

    queue_as :default

    before_enqueue :notify_with_lock

    def priority
      PRIORITY
    end

    def delayed_reference_id
      'db:configure:rebuild_transitive_tables'
    end

    def delayed_reference_type
      REFERENCE_TYPE
    end

    def perform
      Rake::Task.clear
      Rails.application.load_tasks

      ActionCable.server.broadcast('rebuild_classification_mappings', { type: 'lock', message_path: 'dash_board.maintenance.classification_mappings.started' })
      Rake::Task['db:configure:rebuild_transitive_tables'].invoke
      Rake::Task['db:configure:rebuild_transitive_tables'].reenable
      ActionCable.server.broadcast('rebuild_classification_mappings', { type: 'unlock', message_path: 'dash_board.maintenance.classification_mappings.finished' })
    rescue StandardError
      ActionCable.server.broadcast('rebuild_classification_mappings', { type: 'unlock', message_path: 'dash_board.maintenance.classification_mappings.error', message_type: 'alert' })
    end

    private

    def notify_with_lock
      ActionCable.server.broadcast('rebuild_classification_mappings', { type: 'lock', message_path: 'dash_board.maintenance.classification_mappings.queued' })
    end
  end
end
