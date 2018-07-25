# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module Differs
      class BasicDiffer
        attr_reader :diff_hash

        def initialize(a, b, template = nil, parent_key = '')
          @diff_hash = {}
          @parent_key = parent_key
          diff(a, b, template)
        end

        def diff(a, b, template)
        end
      end
    end
  end
end
