# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Abilities
      class ViewMode < DataCycleCore::Ability
        def initialize(_user, _session = {})
          can DataCycleCore.features.dig('view_mode', 'allowed').map(&:to_sym), :view_mode
        end
      end
    end
  end
end
