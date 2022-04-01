# frozen_string_literal: true

module DataCycleCore
  module Export
    class GenericObject
      def init_logging(type)
        return if type.blank?
        if @options&.dig(type, :logging_strategy).blank?
          DataCycleCore::Generic::Logger::LogFile.new(type.to_s)
        else
          instance_eval(@options.dig(type, :logging_strategy))
        end
      end
    end
  end
end
