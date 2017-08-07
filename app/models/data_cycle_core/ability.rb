module DataCycleCore
  class Ability
    include CanCan::Ability

    def initialize(user)
      can :read, DataCycleCore::WatchList, user: user

      can :manage, DataCycleCore::CreativeWork
    end
  end
end
