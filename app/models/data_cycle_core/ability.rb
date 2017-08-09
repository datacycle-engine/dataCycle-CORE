module DataCycleCore
  class Ability
    include CanCan::Ability

    def initialize(user, session)

      if user.role == "admin"
        can :manage, :all
        cannot :manage, DataCycleCore::WatchList
        can :manage, DataCycleCore::WatchList, user: user
        
      elsif user.role == "user"
        can :manage, :all
        cannot :manage, [:dash_board, DataCycleCore::WatchList]
        can :manage, DataCycleCore::WatchList, user: user

        if user.admin?
          can :manage, :dash_board
        end

      elsif user.role == "guest"
        can :read, :all
        cannot :manage, [:dash_board, DataCycleCore::WatchList, :backend]
        
        DataCycleCore::EditLink.where(id: session[:can_edit_ids]).each do |link|
          can [:update, :validate_single_data], link.item_type.constantize, {id: link.item_id}
        end
      end
    end
  end
end
