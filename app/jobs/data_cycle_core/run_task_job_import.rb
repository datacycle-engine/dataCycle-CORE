# frozen_string_literal: true

require 'rake'

module DataCycleCore
  class RunTaskJobImport < UniqueApplicationJob
    PRIORITY = 5 # default for all importer jobs

    REFERENCE_TYPE = 'rake_task_importers'

    queue_as :importers

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0].to_s
    end

    def delayed_reference_type
      REFERENCE_TYPE
    end

    def perform(task, args = [])
      Rake::Task.clear
      Rails.application.load_tasks
      Rake::Task[task].invoke(*Array.wrap(args))
    end
  end
end
