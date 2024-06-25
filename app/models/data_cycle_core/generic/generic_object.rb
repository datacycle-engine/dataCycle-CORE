# frozen_string_literal: true

module DataCycleCore
  module Generic
    class GenericObject
      def init_logging(type)
        return if type.blank?

        if @options&.dig(type, :logging_strategy).blank? && @options&.dig(:logging_strategy).blank?
          DataCycleCore::Generic::Logger::LogFile.new(type.to_s)
        elsif @options&.dig(type, :logging_strategy) == DataCycleCore::Generic::Logger::Instrumentation.to_s || @options&.dig(:logging_strategy) == DataCycleCore::Generic::Logger::Instrumentation.to_s
          DataCycleCore::Generic::Logger::Instrumentation.new(type.to_s)
        else
          instance_eval(@options.dig(type, :logging_strategy)) || instance_eval(@options.dig(:logging_strategy))
        end
      end

      def self.format_float(number, n, m)
        parts = number.round(m).to_s.split('.')
        parts[0].rjust(n) + '.' + parts[1].ljust(m, '0')
      end
    end
  end
end
