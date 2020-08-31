# frozen_string_literal: true

module DataCycleCore
  class Ability
    include CanCan::Ability

    def initialize(user, session = {})
      return unless user
      can :show, :all

      [*0..10, 99].select { |r| r <= user.role&.rank.to_i }.each do |rank|
        merge DataCycleCore::Abilities.const_get("rank_#{rank}".classify).new(user, session)
      end

      DataCycleCore.features.select { |_, v| !v.dig(:only_config) == true }.each_key do |key|
        feature = ('DataCycleCore::Feature::' + key.to_s.classify).constantize
        merge feature.ability_class.new(user, session) if feature.enabled? && feature.ability_class
      end
    end
  end
end
