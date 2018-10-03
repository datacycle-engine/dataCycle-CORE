# frozen_string_literal: true

module Abilities
  module Rank0Extension
    def initialize(_user, _session = {})
      super

      can :create_in_objectbrowser, [DataCycleCore::Person, DataCycleCore::Organization, DataCycleCore::Place]

      can :show_history, DataCycleCore::StoredFilter
    end
  end
end

DataCycleCore::Abilities::Rank0.prepend(Abilities::Rank0Extension)
