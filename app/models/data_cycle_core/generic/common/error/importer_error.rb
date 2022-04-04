# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module Error
        class ImporterError < GenericError
          attr_reader :response

          def initialize(msg, response = '')
            super(msg)
            @response = response
          end
        end
      end
    end
  end
end
