# frozen_string_literal: true

module Abilities
  module Rank0Extension
    def initialize(_user, _session = {})
      super

      can :show_history, DataCycleCore::StoredFilter
      can :bulk_edit, DataCycleCore::WatchList
      can :bulk_delete, DataCycleCore::WatchList
    end
  end
end

DataCycleCore::Abilities::Rank0.prepend(Abilities::Rank0Extension)
