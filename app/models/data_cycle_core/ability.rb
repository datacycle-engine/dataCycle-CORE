module DataCycleCore
  class Ability
    include CanCan::Ability

    def initialize(user, session)

      if user.role == "admin"
        can :manage, :all
        can :read, DataCycleCore::WatchList, user: user
        
      elsif user.role == "user"
        can :manage, :all
        cannot :manage, :dash_board
        can :read, DataCycleCore::WatchList, user: user

      elsif user.role == "guest"
        can :read, :all
        cannot :manage, :dash_board

        links = DataCycleCore::EditLink.where(id: session[:can_edit_ids])
        links.each do |link|
          can [:update, :validate_single_data], link.item_type.constantize, {id: link.item_id}
        end
      end
    end
  end
end
