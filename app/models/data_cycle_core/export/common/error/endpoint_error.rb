# frozen_string_literal: true

module DataCycleCore
  module Export
    module Common
      module Error
        class EndpointError < GenericError
          def initialize(msg, response)
            super(msg + "| #{response.status}: #{response.reason_phrase} | #{response.body}")
          end
        end
      end
    end
  end
end
