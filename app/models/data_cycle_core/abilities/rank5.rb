# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank5 < DataCycleCore::Ability
      TEMPLATES = (['Angebot', 'Artikel', 'Bild', 'Biografie', 'Container',
                    'Interview', 'Linktipps', 'Quiz', 'Rezept', 'SocialMediaPosting',
                    'Video', 'Zeitleiste', 'Lift', 'Örtlichkeit', 'Piste', 'POI',
                    'Tour', 'Unterkunft', 'Event', 'Organization', 'Person'] - DataCycleCore.excluded_new_item_objects).freeze
      # [DataCycleCore::CreativeWork, DataCycleCore::Thing].map { |object| object.where(template: true).where("schema ->> 'content_type' IN ('entity', 'container')").pluck(:template_name) }.flatten
      include CanCan::Ability

      def initialize(user, _session = {})
        can [:read, :create, :update, :destroy], DataCycleCore::DataLink, creator_id: user.id

        # Contents
        can [:show, :new_asset_object, :remove_asset_object], DataCycleCore::Asset

        can [:read, :update, :import, :set_life_cycle, :move_content], CONTENT_MODELS.map(&:constantize) do |content|
          content.try(:external_key).blank? || DataCycleCore::Feature::Overlay.allowed?(content) || content.global_property_names.present?
        end

        # TODO: change when migration is finished
        can :create, TEMPLATES
        can :create_item, '' if TEMPLATES&.size&.positive?

        can :destroy, CONTENT_MODELS do |content|
          content&.created_by_user == user
        end
      end
    end
  end
end
