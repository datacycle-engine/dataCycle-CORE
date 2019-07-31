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
        can :download, DataCycleCore::Thing do |content|
          DataCycleCore::Feature::Download.allowed?(content)
        end
        can [:download], DataCycleCore::WatchList do |_watch_list|
          DataCycleCore::Feature::Download.collection_serializer_enabled?('watch_list')
        end
        can [:download_zip], DataCycleCore::WatchList do |_watch_list|
          DataCycleCore::Feature::Download.collection_enabled?('watch_list')
        end
        can [:download], DataCycleCore::StoredFilter do |_stored_filter|
          DataCycleCore::Feature::Download.collection_serializer_enabled?('stored_filter')
        end
        can [:download_zip], DataCycleCore::StoredFilter do |_stored_filter|
          DataCycleCore::Feature::Download.collection_enabled?('stored_filter')
        end
      end
    end
  end
end
