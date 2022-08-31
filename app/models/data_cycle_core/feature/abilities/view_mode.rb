# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Abilities
      class ViewMode < DataCycleCore::Ability
        # @todo: remove after migrated to new abilities logic
        def initialize(user, _session = {})
          can :grid, :view_mode
          can DataCycleCore.features.dig('view_mode', 'allowed').map(&:to_sym), :view_mode if user.has_rank?(5)
        end
      end
    end
  end
end
