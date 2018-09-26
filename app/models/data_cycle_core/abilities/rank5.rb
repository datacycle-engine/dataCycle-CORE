# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank5
      CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze
      include CanCan::Ability

      def initialize(user, _session = {})
        can [:read, :create, :update, :destroy], DataCycleCore::DataLink, creator_id: user.id

        # Contents
        can [:show, :new_asset_object, :remove_asset_object], DataCycleCore::Asset

        can [:read, :create, :update, :import, :set_life_cycle, :move_content], CONTENT_MODELS do |content|
          content.try(:external_key).blank? || DataCycleCore::Feature::Overlay.allowed?(content) || content.global_property_names.present?
        end
        can :destroy, CONTENT_MODELS do |content|
          content&.created_by_user == user
        end
      end
    end
  end
end
