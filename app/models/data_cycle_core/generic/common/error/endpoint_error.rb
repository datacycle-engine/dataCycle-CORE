# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Error
        class EndpointError < StandardError
          def initialize(msg, response)
            super(msg + "| #{response.status}: #{response.reason_phrase} | #{response.body}")
          end
        end
      end
    end
  end
end
