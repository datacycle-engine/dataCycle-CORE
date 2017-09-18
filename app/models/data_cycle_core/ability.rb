module DataCycleCore
  class Ability
    include CanCan::Ability

    def initialize(user, session = {})

      if user
        can :read, :all
        cannot :read, DataCycleCore::WatchList
        can [:show, :find], :object_browser

        if user.role == "admin" || user.role == "user"
          can :manage, [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]
          can :manage, DataCycleCore::WatchList, user_id: user.id

          can :subscribe, [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]
          can [:create, :destroy], DataCycleCore::Subscription

          can :manage, DataCycleCore::DataLink
        end

        if user.role == "admin" || user.admin?
          can :manage, :dash_board
          can :manage, DataCycleCore::User
          cannot :set_role, DataCycleCore::User do |the_user|
            the_user.role == "admin"
          end

        elsif user.role == "user"
          can :manage, DataCycleCore::User, id: user.id
          cannot :set_role, DataCycleCore::User

        elsif user.role == "guest"
          DataCycleCore::DataLink.session_edit_links(session[:can_edit_ids]).each do |link|
            can [:update, :validate_single_data], link.item_type.constantize, {id: link.item_id}
          end
        end
      end
    end
  end
end
