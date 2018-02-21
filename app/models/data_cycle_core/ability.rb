module DataCycleCore
  class Ability
    include CanCan::Ability

    def initialize(user, session = {})
      alias_action :update, :destroy, to: :modify
      alias_action :create, :import, :read, :update, :create_user, :search, :unlock, :validate_single_data, to: :crud

      if user
        can :read, :all
        cannot :read, [DataCycleCore::WatchList, DataCycleCore::StoredFilter]
        cannot :read, :backend
        can :search, DataCycleCore::User
        can [:show, :find], :object_browser

        if user.has_rank?(0)
          DataCycleCore::DataLink.session_edit_links(session[:can_edit_ids]).each do |link|
            can [:update, :validate_single_data, :import], link.item_type.constantize, { id: link.item_id } if link.is_valid?
          end
        end

        if user.has_rank?(1)
          can [:read, :settings, :store_filter], :backend
          can :modify, DataCycleCore::User, id: user.id
          can :manage, DataCycleCore::WatchList, user_id: user.id
          can [:read, :create, :destroy], DataCycleCore::StoredFilter, user_id: user.id
          can :read, DataCycleCore::StoredFilter, system: true
          can :show_publications, DataCycleCore::Content
          can [:subscribe, :history, :history_detail], [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]
        end

        if user.has_rank?(10)
          can :manage, [DataCycleCore::DataLink, DataCycleCore::Classification]
          can [:crud, :destroy], DataCycleCore::UserGroup
          can [:crud, :destroy], DataCycleCore::User do |the_user|
            user&.role&.rank&.> the_user&.role&.rank || the_user == user
          end

          can :update_release_status, [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]

          can :manage,
              [
                DataCycleCore::Classification,
                DataCycleCore::ClassificationTreeLabel,
                DataCycleCore::ClassificationTree,
                DataCycleCore::ClassificationAlias
              ],
              external_source_id: nil

          can :crud, [DataCycleCore::CreativeWork, DataCycleCore::Event, DataCycleCore::Person, DataCycleCore::Place] do |data_object|
            data_object&.schema&.dig('permissions', 'read_write') != false
          end

          can [:set_role, :set_user_groups], DataCycleCore::User do |the_user|
            !the_user.has_rank?(user.role.rank) || user == the_user
          end
          can :destroy, [DataCycleCore::CreativeWork, DataCycleCore::Event, DataCycleCore::Person, DataCycleCore::Place] do |data_object|
            data_object&.schema&.dig('permissions', 'read_write') != false && data_object.try(:external_key).nil?
          end

          can :set_life_cycle, DataCycleCore::CreativeWork

          can :manage, DataCycleCore::Asset
          can :create_global, DataCycleCore::StoredFilter
        end

        can :manage, :dash_board if user.has_rank?(10) && (user.email =~ /@pixelpoint\.at/ || user.email =~ /@datacycle\.at/)

        can :edit, DataCycleCore::DataAttribute do |attribute|
          !attribute.options['readonly']
        end

        unless user.email =~ /@pixelpoint\.at/ || user.email =~ /@datacycle\.at/
          cannot :modify, DataCycleCore::User do |the_user|
            the_user.has_rank?(user.role.try(:rank)) && the_user != user
          end
        end
      end
    end
  end
end
