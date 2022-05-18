# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank1 < DataCycleCore::Ability
      def initialize(user, _session = {})
        can :create_duplicate, DataCycleCore::Asset
        can [:show_related, :show_external_connections], DataCycleCore::Thing

        can [:read, :settings], :backend
        can [:search, :classification_trees, :classification_tree, :permanent_advanced, :advanced, :publication_date], [:backend, :classification_tree, :publications, :subscriptions, :things, :collection]
        can :advanced_filter, [:backend, :classification_tree, :publications, :subscriptions, :things, :collection] do |_t, _k, v|
          (v != 'classification_tree_ids' && v != 'advanced_attributes')
        end
        can :update, DataCycleCore::User, id: user.id
        can [:read, :create, :update, :destroy, :show_history], DataCycleCore::StoredFilter, user_id: user.id
        can :read, DataCycleCore::StoredFilter, system: true
        can :read, [DataCycleCore::Subscription, :publication]
        can [:subscribe, :history], DataCycleCore::Thing
<<<<<<< HEAD
=======
        can [:history], DataCycleCore::Thing::History
>>>>>>> old/develop

        can [:read, :create, :update, :add_item, :remove_item], DataCycleCore::WatchList, user_id: user.id
        can [:destroy, :change_owner, :share], DataCycleCore::WatchList, user_id: user.id, my_selection: false
        can [:read, :add_item, :remove_item], DataCycleCore::WatchList, watch_list_shares: { shareable_id: user.user_group_ids, shareable_type: 'DataCycleCore::UserGroup' }
        can [:read, :add_item, :remove_item], DataCycleCore::WatchList, watch_list_shares: { shareable_id: user.id, shareable_type: 'DataCycleCore::User' }
      end
    end
  end
end
