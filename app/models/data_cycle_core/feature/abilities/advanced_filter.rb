# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Abilities
      class AdvancedFilter
        include CanCan::Ability

        def initialize(_user, _session = {})
        end
      end
    end
  end
end