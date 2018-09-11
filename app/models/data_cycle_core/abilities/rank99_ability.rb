# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank99Ability
      CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze
      include CanCan::Ability

      def initialize(_user, _session = {})
        can :manage, :dash_board
        can :become, DataCycleCore::User
      end
    end
  end
end
