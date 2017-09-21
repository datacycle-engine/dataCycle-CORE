module DataCycleCore
  class Ability
    include CanCan::Ability

    def initialize(user, session = {})
      alias_action :update, :destroy, to: :modify

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
          can :manage, [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]
          can :manage, DataCycleCore::WatchList, user_id: user.id
          can :read, :backend

          can :subscribe, [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]
          can [:create, :destroy], DataCycleCore::Subscription

          can :manage, DataCycleCore::DataLink

          can :modify, DataCycleCore::User, id: user.id
        end

        if user.has_rank?(2)
          can :manage, :dash_board
          can :manage, [DataCycleCore::User, DataCycleCore::UserGroup]
          cannot [:set_role, :set_user_groups], DataCycleCore::User do |the_user|
            the_user.has_rank?(user.role.rank)
          end
          cannot [:set_role, :set_user_groups], DataCycleCore::User do |the_user|
            the_user.has_rank?(user.role.rank)
          end
        end

        cannot :modify, DataCycleCore::User do |the_user|
          the_user.external || the_user.role.rank < 1
        end
      end
    end
  end
end
