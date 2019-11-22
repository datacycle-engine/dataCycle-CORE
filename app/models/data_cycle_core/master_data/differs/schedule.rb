# frozen_string_literal: true

require 'hashdiff'

module DataCycleCore
  module MasterData
    module Differs
      class Schedule < Basic
        def diff(a, b, _template)
          a_hash = a.is_a?(DataCycleCore::Schedule) || a.is_a?(IceCube::Schedule) ? a.to_h : a
          b_hash = b.is_a?(DataCycleCore::Schedule) || b.is_a?(IceCube::Schedule) ? b.to_h : b
          @diff_hash = generic_diff(a_hash, b_hash, method(:schedule_comp).to_proc)
        end

        def schedule_comp(a, b)
          return true if a == b
          ::Hashdiff.diff(a, b).blank?
        end
      end
    end
  end
end
