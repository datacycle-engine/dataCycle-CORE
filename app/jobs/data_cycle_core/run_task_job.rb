# frozen_string_literal: true

module DataCycleCore
  class RunTaskJob < UniqueApplicationJob
    queue_as :default
    queue_with_priority 0
    # deduplicated by task *and* arguments, like the delayed_reference_id/_type pair it replaces:
    # running the same task twice concurrently is never wanted, but two vacuums of different tables
    # are unrelated. Duplicates are dropped rather than queued behind the original, since by the
    # time the first one finishes the second has nothing left to do.
    limits_concurrency key: ->(*args) { "#{args[0]}/#{Array.wrap(args[1]).flatten.join('_')}" }, on_conflict: :discard

    def perform(task, args = [])
      DataCycleCore::RakeTaskService.invoke(task, args)
    end
  end
end
