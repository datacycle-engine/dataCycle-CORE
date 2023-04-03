# frozen_string_literal: true

module DataCycleCore
  module ApiRenderer
    module Error
      class RendererError < StandardError
        def initialize(msg = '')
          super
        end
      end
    end
  end
end
