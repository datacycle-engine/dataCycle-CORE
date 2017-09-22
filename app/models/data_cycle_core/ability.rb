module DataCycleCore
  class Ability
    include CanCan::Ability

    def initialize(user, session = {})
      alias_action :update, :destroy, to: :modify
      alias_action :create, :create_user, :unlock, :read, :update, :destroy, :validate_single_data, to: :crud

      if user
        can :read, :all
        cannot :read, DataCycleCore::WatchList
        cannot :read, :backend
        can [:show, :find], :object_browser

        if user.has_rank?(0)
          DataCycleCore::DataLink.session_edit_links(session[:can_edit_ids]).each do |link|
            can [:update, :validate_single_data], link.item_type.constantize, {id: link.item_id}
          end
        end

        if user.has_rank?(1)
          can :read, :backend
          can :modify, DataCycleCore::User, id: user.id
          can :manage, DataCycleCore::WatchList, user_id: user.id
          can :subscribe, [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]
        end

        if user.has_rank?(10)
          can :manage,
            [
              :dash_board,
              DataCycleCore::DataLink
            ]

            can :crud,
            [
              DataCycleCore::User,
              DataCycleCore::UserGroup,
              DataCycleCore::CreativeWork,
              DataCycleCore::Person,
              DataCycleCore::Place
            ]

          can [:set_role, :set_user_groups], DataCycleCore::User do |the_user|
            !the_user.has_rank?(user.role.rank)
          end
        end

        cannot :modify, DataCycleCore::User do |the_user|
          (the_user.role && the_user.role.rank == 0) || (the_user.has_rank?(user.role.try(:rank)) && the_user != user)
        end
      end
    end
  end
end
