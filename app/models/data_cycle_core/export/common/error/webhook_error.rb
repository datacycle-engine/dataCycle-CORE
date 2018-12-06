# frozen_string_literal: true

module DataCycleCore
  module Export
    module Common
      module Error
        class WebhookError < GenericError
          def initialize(msg = '')
            super
          end
        end
      end
    end
  end
end
