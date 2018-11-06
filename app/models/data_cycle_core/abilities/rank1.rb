# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank1 < DataCycleCore::Ability
      def initialize(user, _session = {})
        can [:read, :settings, :advanced_filter], :backend
        can :update, DataCycleCore::User, id: user.id
        can [:read, :create, :update, :destroy, :show_history], DataCycleCore::StoredFilter, user_id: user.id
        can :read, DataCycleCore::StoredFilter, system: true
        can :read, [DataCycleCore::Subscription, :publication]
        can [:subscribe, :history], CONTENT_MODELS.map(&:constantize)

        can [:read, :create, :update, :destroy], DataCycleCore::WatchList, user_id: user.id
        can [:add_item, :remove_item], DataCycleCore::WatchList, user_id: user.id, valid_write_links?: false

        can :read, DataCycleCore::WatchList, watch_list_user_groups: { user_group_id: user.user_group_ids }
        can [:add_item, :remove_item], DataCycleCore::WatchList, valid_write_links?: false, watch_list_user_groups: { user_group_id: user.user_group_ids }

        can :show, DataCycleCore::DataAttribute do |attribute|
          DataCycleCore::Feature::Releasable.allowed_attribute_keys(attribute.content).include?(attribute.key.attribute_name_from_key)
        end
      end
    end
  end
end
