# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Abilities
      class ReportGenerator < DataCycleCore::Ability
        def initialize(user, _session = {})
          can :manage, :report if user.has_rank?(99)
        end
      end
    end
  end
end
