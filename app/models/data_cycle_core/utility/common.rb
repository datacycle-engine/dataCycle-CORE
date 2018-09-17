# frozen_string_literal: true

module DataCycleCore
  module Utility
    module Common
      class << self
        def sum(a,b)
          a+b
        end
        def test_1(*a)
          a.to_a
        end
        def test_2(a, *b)
          a+b.to_a
        end
        def test_3
          'test3'
        end
      end
    end
  end
end
