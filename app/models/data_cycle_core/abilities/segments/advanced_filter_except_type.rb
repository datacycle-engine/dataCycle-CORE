# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Segments
      class AdvancedFilterExceptType < Base
        attr_reader :subject, :except_types

        def initialize(subject, except_types = [])
          @except_types = Array.wrap(except_types).map(&:to_s)
          @subject = Array.wrap(subject).map(&:to_sym)
        end

        def include?(_view, _name = nil, type = nil, *_args)
          except_types.exclude?(type.to_s)
        end

        def to_proc
          ->(*args) { include?(*args) }
        end
      end
    end
  end
end
