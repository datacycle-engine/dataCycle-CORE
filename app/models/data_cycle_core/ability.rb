# frozen_string_literal: true

module DataCycleCore
  class Ability
    CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze

    include CanCan::Ability

    def initialize(user, session = {})
      return unless user
      can :show, :all

      [*0..5, 10, 99].select { |r| r <= user.role&.rank.to_i }.each do |rank|
        merge DataCycleCore::Abilities.const_get("rank_#{rank}".classify).new(user, session)
      end

      DataCycleCore.features.select { |_, v| v[:enabled] }.each_key do |key|
        merge DataCycleCore::Feature::Abilities.const_get(key.to_s.classify).new(user, session)
      end
    end
  end
end
