# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Error
        class EndpointError < GenericError
          attr_reader :response

          def initialize(msg, response = nil)
            if response.nil?
              super(msg)
            else
              super(msg + "| #{response&.status}: #{response&.reason_phrase} | #{response&.body&.encode('utf-8', invalid: :replace, undef: :replace, replace: '_')}")
            end
            @response = response
          end
        end
      end
    end
  end
end
