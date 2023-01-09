# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank5 < DataCycleCore::Ability
      include CanCan::Ability

      def initialize(user, _session = {})
        can [:read, :create, :update, :destroy], DataCycleCore::DataLink, creator_id: user.id
        can [:create, :update, :destroy], DataCycleCore::Asset, creator_id: user&.id

        can [:create, :destroy], :auto_translate

        can [:view_life_cycle], DataCycleCore::Thing

        can [:read, :update, :import, :set_life_cycle, :move_content], DataCycleCore::Thing do |content|
          content.try(:external_source_id).blank? ||
            DataCycleCore::Feature::Overlay.allowed?(content) ||
            content.global_property_names.present?
        end

        can :create, DataCycleCore::Thing do |template, scope|
          template&.creatable?(scope)
        end

        can :destroy, DataCycleCore::Thing do |content|
          content&.created_by_user == user
        end
      end
    end
  end
end
