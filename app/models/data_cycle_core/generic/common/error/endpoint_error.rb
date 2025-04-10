# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Error
        class EndpointError < GenericError
          attr_reader :response

          def initialize(msg, response = nil, status = nil)
            @response = response
            @status = status

            if response.nil?
              super(msg)
            else
              super(msg + "| #{status}: #{response&.reason_phrase} | #{response&.body&.to_s&.encode('utf-8', invalid: :replace, undef: :replace, replace: '_')}")
            end
          end

          def status
            @response&.status || @status
          end
        end
      end
    end
  end
end
