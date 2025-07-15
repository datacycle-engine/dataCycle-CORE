# frozen_string_literal: true

# inspired by Turbo::ThreadDebouncer
module DataCycleCore
  module Turbo
    class ThreadThrottler
      delegate :wait, to: :throttler

      def self.for(key, interval: Turbo::Throttler::DEFAULT_INTERVAL)
        Thread.current[key] ||= new(key, Thread.current, interval: interval)
      end

      private_class_method :new

      def initialize(key, thread, interval:)
        @key = key
        @throttler = Turbo::Throttler.new(interval: interval)
        @thread = thread
      end

      def throttle
        throttler.throttle do |initial|
          yield.tap do
            thread[key] = nil unless initial
          end
        end
      end

      private

      attr_reader :key, :throttler, :thread
    end
  end
end
