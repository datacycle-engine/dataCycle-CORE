# frozen_string_literal: true

module DataCycleCore
  module DiffService
    require 'hashdiff'

    module_function

    def dirty?(a, b)
      diff(a.to_h, b.to_h).count.positive?
    end

    def diff(a, b)
      HashDiff.diff(a, b)
    end
  end
end
