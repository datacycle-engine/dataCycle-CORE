# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank99 < DataCycleCore::Ability
      def initialize(_user, _session = {})
        can [:read, :create, :update, :destroy, :show_history], DataCycleCore::StoredFilter
        can :manage, :dash_board
        can [:become, :show_representation_of, :change_ui_locale], DataCycleCore::User
        can :manage, DataCycleCore::ClassificationTreeLabel
        can :manage, DataCycleCore::ClassificationAlias
<<<<<<< HEAD
        # can :update, DataCycleCore::DataAttribute
=======
        # can :update, DataCycleCore::DataAttribute if Rails.env.development?
>>>>>>> old/develop
        can [:update, :destroy, :show_admin_panel], DataCycleCore::Thing
        can [:bulk_edit, :bulk_delete], DataCycleCore::WatchList
        can :api, DataCycleCore::StoredFilter
        can [:advanced_filter, :sortable], :backend
        can :show_admin_activities, :dash_board
        can [:create_api, :create_api_with_users], DataCycleCore::StoredFilter
        can :restore_version, DataCycleCore::Thing::History
        can [:create, :destroy], :auto_translate
      end
    end
  end
end
