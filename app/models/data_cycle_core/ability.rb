module DataCycleCore
  class Ability
    include CanCan::Ability

    def initialize(user)
      can :read, DataCycleCore::WatchList, user: user
    end
  end
end
