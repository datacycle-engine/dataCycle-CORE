module DataCycleCore
  module Abilities
    class Rank1Ability
      CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze
      include CanCan::Ability

      def initialize(user, _session = {})
        can [:read, :settings], :backend
        can [:show, :update], DataCycleCore::User, id: user.id
        can [:read, :create, :update, :destroy, :show_history], DataCycleCore::StoredFilter, user_id: user.id
        can :read, DataCycleCore::StoredFilter, system: true
        can :read, [DataCycleCore::Subscription, :publication]
        can [:subscribe, :history, :history_detail], CONTENT_MODELS

        can [:read, :create, :update, :destroy], DataCycleCore::WatchList, user_id: user.id
        can [:add_item, :remove_item], DataCycleCore::WatchList do |watch_list|
          watch_list.data_links.none? { |d| d.is_valid? && d.permissions == 'write' } && watch_list.user_id == user.id
        end
      end
    end
  end
end
