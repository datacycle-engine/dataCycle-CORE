# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank99
      CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze
      include CanCan::Ability

      def initialize(_user, _session = {})
        can :manage, :dash_board
        can :become, DataCycleCore::User
        can :map_classifications, DataCycleCore::ClassificationAlias
        can :destroy, DataCycleCore::ClassificationTreeLabel
        can :destroy, DataCycleCore::ClassificationAlias
      end
    end
  end
end