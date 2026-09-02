# frozen_string_literal: true

module DataCycleCore
  # rebuilds errors that were marshalled out of a forked child process
  class ErrorService
    class << self
      # rebuilds an error as its original class, degrading to a ForkedProcessError when that fails
      def rebuild(error_class, message, backtrace = nil)
        # a message assembled from an external payload can carry invalid bytes, which make blank?/include? raise
        message = message.to_s.scrub('')
        return if error_class.blank? && message.blank?

        error = build(error_class, message) || DataCycleCore::Error::ForkedProcessError.new([error_class, message].compact_blank.join(': '))
        apply_backtrace(error, backtrace)
        error
      end

      private

      # rebuilding must neither raise nor drop the message, that would mask the error of the child process
      def build(error_class, message)
        klass = error_class.to_s.safe_constantize
        return unless klass.is_a?(Class) && klass <= StandardError

        error = klass.new(message)
        error if message.blank? || error.message.to_s.include?(message.to_s)
      rescue StandardError, ScriptError, SystemStackError
        nil
      end

      def apply_backtrace(error, backtrace)
        error.set_backtrace(backtrace) if backtrace.present?
      rescue StandardError
        nil
      end
    end
  end
end
