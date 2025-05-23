# frozen_string_literal: true

module DataCycleCore
  module Loggers
    class InstrumentationLogger < Logger
      SEVERITIES = [:debug, :info, :warn, :error, :fatal].freeze

      def initialize(type:)
        log_file = "./log/#{type}.log"
        @kind_short = "[#{type.to_s[0].upcase}]"
        super(log_file)
      end

      def dc_log(severity, data)
        severity = :info unless SEVERITIES.include?(severity)

        case data
        when ::Array
          message = data.join("\n")
        when ::Hash
          message = data[:message]

          if severity == :error && message.blank?
            message = [@kind_short]

            if data[:step_label].present?
              message.push(data[:step_label], '...', '[FAILED]')
            else
              message.push(data[:external_system]&.name, '...', '[FAILED]')
            end

            message.push("(Item-ID: #{data[:item_id]})") if data[:item_id].present?

            if data[:exception].present?
              formatted_backtrace = data[:exception].backtrace.filter { |line| line.exclude?('/bundle') }.join("\n")
              message.push("(Exception: #{data[:exception]}, Backtrace: #{formatted_backtrace})")
            end
            message = message.join(' ')
          end
        when ::String
          message = data
        else
          message = data.to_json
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
