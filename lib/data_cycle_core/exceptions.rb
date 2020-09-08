# frozen_string_literal: true

module DataCycleCore
  module Error
    module Api
      class InvalidArgumentError < StandardError
      end
      class TimeOutError < StandardError
      end
      class BadRequest < StandardError
        attr_reader :data

        def initialize(data)
          @data = data
          super
        end
      end
    end
    module Download
      class InvalidSerializationFormatError < StandardError
      end
    end
    class RecordNotFoundError < StandardError
    end
    class DeprecatedMethodError < StandardError
    end
  end
end
