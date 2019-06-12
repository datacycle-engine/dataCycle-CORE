# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank1 < DataCycleCore::Ability
      def initialize(user, _session = {})
        can :create_duplicate, DataCycleCore::Asset

        can [:read, :settings], :backend
        can :advanced_filter, :backend do |_t, _k, v|
          v != 'classification_tree_ids'
        end
        can :update, DataCycleCore::User, id: user.id
        can [:read, :create, :update, :destroy, :show_history], DataCycleCore::StoredFilter, user_id: user.id
        can :read, DataCycleCore::StoredFilter, system: true
        can :read, [DataCycleCore::Subscription, :publication]
        can [:subscribe, :history], DataCycleCore::Thing

        can [:read, :create, :update, :destroy, :add_item, :remove_item], DataCycleCore::WatchList, user_id: user.id
        can [:read, :add_item, :remove_item], DataCycleCore::WatchList, watch_list_shares: { shareable_id: user.user_group_ids, shareable_type: 'DataCycleCore::UserGroup' }
        can [:read, :add_item, :remove_item], DataCycleCore::WatchList, watch_list_shares: { shareable_id: user.id, shareable_type: 'DataCycleCore::User' }
      end
    end
  end
end
