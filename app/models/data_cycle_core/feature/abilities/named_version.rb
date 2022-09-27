# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Abilities
      class NamedVersion < DataCycleCore::Ability
        # @todo: remove after migration to new abilities logic
        def initialize(user, _session = {})
          can :remove_version_name, [DataCycleCore::Thing, DataCycleCore::Thing::History] if user.has_rank?(10)
        end
      end
    end
  end
end
