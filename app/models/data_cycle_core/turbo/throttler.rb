# frozen_string_literal: true

# inspired by Turbo::Throttler
module DataCycleCore
  module Turbo
    class Throttler
      attr_reader :interval, :scheduled_task

      DEFAULT_INTERVAL = 1

      def initialize(interval: DEFAULT_INTERVAL)
        @interval = interval
        @scheduled_task = nil
      end

      def throttle(&)
        if scheduled_task.nil?
          yield(true)
          @scheduled_task = Concurrent::ScheduledTask.execute(interval, &)
        elsif scheduled_task&.complete?
          @scheduled_task = Concurrent::ScheduledTask.execute(interval, &)
        end
      end

      def wait
        scheduled_task&.wait(interval)
      end
    end
  end
end
