# frozen_string_literal: true

require 'rake'

module DataCycleCore
  class RunTaskJob < UniqueApplicationJob
    PRIORITY = 0

    REFERENCE_TYPE = 'RAKE_TASK'

    queue_as :default

    def priority
      PRIORITY
    end

    def delayed_reference_id
      "args:#{Array.wrap(arguments)[1..].flatten.join('_')}"
    end

    def delayed_reference_type
      "#{REFERENCE_TYPE}: #{Array.wrap(arguments).first}"
    end

    def perform(task, args = [])
      Rake::Task.clear
      Rails.application.load_tasks
      Rake::Task[task].invoke(*Array.wrap(args))
    end
  end
end
