# frozen_string_literal: true

module DataCycleCore
  module ApiRenderer
    module Error
      class RendererError < StandardError
        attr_reader :status_code

        def initialize(msg = '', status_code = :bad_request)
          @status_code = status_code
          super(msg)
        end
      end
    end
  end
end
