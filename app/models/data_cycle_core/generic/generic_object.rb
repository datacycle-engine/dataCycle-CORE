# frozen_string_literal: true

module DataCycleCore
  module Generic
    class GenericObject
      def init_logging(type)
        return if type.blank?

        DataCycleCore::Generic::Logger::Instrumentation.new(type.to_s)
      end

      def self.format_float(number, n, m)
        parts = number.round(m).to_s.split('.')
        parts[0].rjust(n) + '.' + parts[1].ljust(m, '0')
      end
    end
  end
end
