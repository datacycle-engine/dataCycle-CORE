# frozen_string_literal: true

module DataCycleCore
  module Loggers
    class InstrumentationLogger < Logger
      def initialize(type:)
        log_file = "./log/#{type}.log"
        @type = type
        super(log_file)
      end

      def dc_log(severity, message_or_data)
        severity = :info unless [:debug, :info, :warn, :error, :fatal].include?(severity)

        if message_or_data.is_a?(Array)
          message = message_or_data.join("\n")
        elsif message_or_data.is_a?(Hash)
          message = message_or_data.dig(:logging_options, :logging_message) ||
                    message_or_data.dig(:message) ||
                    ([:error].include?(severity) ? "#{@type} #{message_or_data.dig(:external_system)&.name} failed (#{message_or_data.dig(:exception)&.to_s})" : nil)
        elsif message_or_data.is_a?(String)
          message = message_or_data
        else
          message = message_or_data.to_json
        end

        send(severity, message) if message.present?
      end

      def self.with_logger(type:)
        logger = new(type:)
        yield(logger)
      ensure
        logger.close
      end
    end
  end
end
