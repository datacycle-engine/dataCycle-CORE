# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      class ExternalKeyProxy < String
        attr_reader :priority

        def initialize(value, priority = nil)
          super(value.to_s)

          @priority = priority
        end

        # used in transformation_functions strip_all
        def strip
          ExternalKeyProxy.new(super, priority)
        end
      end
    end
  end
end
