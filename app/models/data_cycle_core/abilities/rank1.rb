# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank1
      CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze
      include CanCan::Ability

      def initialize(user, _session = {})
        can [:read, :settings, :advanced_filter], :backend
        can :update, DataCycleCore::User, id: user.id
        can [:read, :create, :update, :destroy, :show_history], DataCycleCore::StoredFilter, user_id: user.id
        can :read, DataCycleCore::StoredFilter, system: true
        can :read, [DataCycleCore::Subscription, :publication]
        can [:subscribe, :history], CONTENT_MODELS

        can [:read, :create, :update, :destroy], DataCycleCore::WatchList, user_id: user.id
        can [:add_item, :remove_item], DataCycleCore::WatchList, user_id: user.id, valid_write_links?: false

        can :read, DataCycleCore::WatchList, watch_list_user_groups: { user_group_id: user.user_group_ids }
        can [:add_item, :remove_item], DataCycleCore::WatchList, valid_write_links?: false, watch_list_user_groups: { user_group_id: user.user_group_ids }
      end
    end
  end
end