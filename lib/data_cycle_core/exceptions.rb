# frozen_string_literal: true

module DataCycleCore
  module Error
    module Api
      class InvalidArgumentError < StandardError
      end
    end
    class RecordNotFoundError < StandardError
    end
  end
end
