module DataCycleCore
  class Ability
    include CanCan::Ability

    def initialize(user, session = {})

      if user
        can :read, :all
        cannot :read, DataCycleCore::WatchList

        if user.role == "admin" || user.role == "user"
          can :manage, [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]
          can :manage, DataCycleCore::WatchList, user_id: user.id

          can :subscribe, [DataCycleCore::Person, DataCycleCore::CreativeWork, DataCycleCore::Place]
          can [:create, :destroy], DataCycleCore::Subscription
        end

        if user.role == "admin" || user.admin?
          can :manage, :dash_board

        elsif user.role == "user"

        elsif user.role == "guest"
          DataCycleCore::DataLink.session_edit_links(session[:can_edit_ids]).each do |link|
            can [:update, :validate_single_data], link.item_type.constantize, {id: link.item_id}
          end
        end
      end
    end
  end
end
