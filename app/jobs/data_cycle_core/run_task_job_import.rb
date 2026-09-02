# frozen_string_literal: true

module DataCycleCore
  class RunTaskJobImport < UniqueApplicationJob
    queue_as :importers
    queue_with_priority 5
    limits_concurrency key: ->(*args) { args[0].to_s }, on_conflict: :discard

    def perform(task, args = [])
      DataCycleCore::RakeTaskService.invoke(task, args)
    end
  end
end
