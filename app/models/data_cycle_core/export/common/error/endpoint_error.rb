# frozen_string_literal: true

module DataCycleCore
  module Export
    module Common
      module Error
        class EndpointError < GenericError
          attr_reader :response

          def initialize(msg, response)
            super(msg + "| #{response.status}: #{response.reason_phrase} | #{response.body}")
            @response = response
          end
        end
      end
    end
  end
end
