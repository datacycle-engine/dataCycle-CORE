# frozen_string_literal: true

module Abilities
  class Rank0Ability
    CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze
    include CanCan::Ability

    def initialize(_user, _session = {})
      can :create_in_objectbrowser, [DataCycleCore::Person, DataCycleCore::Organization, DataCycleCore::Place]

      can :show_history, DataCycleCore::StoredFilter
    end
  end
end
