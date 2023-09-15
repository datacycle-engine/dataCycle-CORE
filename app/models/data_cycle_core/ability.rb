# frozen_string_literal: true

module DataCycleCore
  class Ability
    include CanCan::Ability

    attr_accessor :user, :session

    def initialize(user, session = {})
      return unless user

      @user = user
      @session = session

      DataCycleCore::Abilities::PermissionsList.add_abilities_for_user(self)
    end
  end
end
