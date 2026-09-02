# frozen_string_literal: true

module DataCycleCore
  module Loggers
    class InstrumentationLogger < Logger
      SEVERITIES = [:debug, :info, :warn, :error, :fatal].freeze

      def initialize(type:)
        log_file = "./log/#{type}.log"
        @type = type
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
              message.push(data[:external_system].try(:name), '...', '[FAILED]')
            end

            message.push("(Item-ID: #{data[:item_id]})") if data[:item_id].present?

            # +exception_object+ is Rails' conventional key for the exception itself, and what the
            # ".active_job" payloads carry (JobExtensions::Callbacks#instrument_error) — there
            # +exception+ is the conventional [class name, message] pair, which has no backtrace.
            # The datacycle-namespaced importer payloads predate that split and pass the object under
            # +exception+ or +error+, so both stay as fallbacks, probed rather than assumed.
            exception = data[:exception_object] if data[:exception_object].respond_to?(:backtrace)
            exception = data[:exception] if exception.nil? && data[:exception].present? && data[:exception].respond_to?(:backtrace)
            exception = data[:error] if exception.nil? && data[:error].present? && data[:error].respond_to?(:backtrace)

            if exception.present?
              # an exception that was never raised has no backtrace, and the logger must not be the
              # thing that fails while reporting a failure
              formatted_backtrace = Array.wrap(exception.backtrace).filter { |line| line.exclude?('/bundle') }.join("\n")
              message.push("(Exception: #{DataCycleCore::Error.describe(exception)}, Backtrace: #{formatted_backtrace})")
            end
            message = message.join(' ')
          end
        when ::String
          message = data
        else
          message = data.to_json
        end

        return if message.blank?

        send(severity, message)
        broadcast_line(severity, message) if @type.in?(['import', 'download'])
      end

      def self.with_logger(type:)
        logger = new(type:)
        yield(logger)
      ensure
        logger.close
      end

      private

      def broadcast_line(severity, message)
        DataCycleCore::TurboService.broadcast_append_to(
          'admin_dashboard_live_log',
          target: 'admin-dashboard-live-log-content',
          html: format_message(format_severity(self.class.const_get(severity.upcase)), Time.current, nil, message)
        )
      end
    end
  end
end
