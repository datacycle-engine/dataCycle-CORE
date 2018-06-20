# frozen_string_literal: true

module DataCycleCore
  class Ability
    CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze

    include CanCan::Ability
    include DataCycleCore::Abilities

    def initialize(user, session = {})
      return unless user
      can :show, :all

      (user.role&.rank.to_i + 1).times do |rank|
        begin
          merge DataCycleCore::Abilities.const_get("rank_#{rank}_ability".classify).new(user, session)
        rescue NameError
          nil
        end
      end
    end
  end
end
