# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Error
        class EndpointError < GenericError
          attr_reader :response

          def initialize(msg, response)
            super(msg + "| #{response&.status}: #{response&.reason_phrase} | #{response&.body&.encode('utf-8', invalid: :replace, undef: :replace, replace: '_')}")
            @response = response
          end
        end
      end
    end
  end
end
