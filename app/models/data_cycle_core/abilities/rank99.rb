# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank99 < DataCycleCore::Ability
      def initialize(_user, _session = {})
        can [:read, :create, :update, :destroy, :show_history], DataCycleCore::StoredFilter
        can :manage, :dash_board
        can :become, DataCycleCore::User
        can :manage, DataCycleCore::ClassificationTreeLabel
        can :manage, DataCycleCore::ClassificationAlias
        can :edit, DataCycleCore::DataAttribute
        can :show_admin_panel, DataCycleCore::Thing
        can :destroy, DataCycleCore::Thing
        can :show_related, DataCycleCore::Thing
        can [:bulk_edit, :bulk_delete], DataCycleCore::WatchList
      end
    end
  end
end
