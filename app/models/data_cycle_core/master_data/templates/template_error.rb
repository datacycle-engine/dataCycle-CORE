# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Templates
      class TemplateError < StandardError
        attr_reader :path

        def initialize(path = nil)
          @path = path
          super
        end
      end
    end
  end
end
