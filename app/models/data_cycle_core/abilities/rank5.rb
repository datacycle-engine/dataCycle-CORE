# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank5 < DataCycleCore::Ability
      # TODO: remove TEMPLATES constant
      TEMPLATES = (['Angebot', 'Artikel', 'Bild', 'Biografie', 'Container',
                    'Interview', 'Linktipps', 'Quiz', 'Rezept', 'SocialMediaPosting',
                    'Video', 'Zeitleiste', 'Lift', 'Örtlichkeit', 'Piste', 'POI',
                    'Tour', 'Unterkunft', 'Event', 'Organization', 'Person',
                    'DataCycle - Datei', 'DataCycle - Audio', 'DataCycle - Bild', 'DataCycle - PDF', 'DataCycle - Video'] - DataCycleCore.excluded_new_item_objects).freeze
      # [DataCycleCore::CreativeWork, DataCycleCore::Thing].map { |object| object.where(template: true).where("schema ->> 'content_type' IN ('entity', 'container')").pluck(:template_name) }.flatten
      include CanCan::Ability

      def initialize(user, _session = {})
        can [:read, :create, :update, :destroy], DataCycleCore::DataLink, creator_id: user.id

        # Contents
        can [:show, :new_asset_object, :remove_asset_object], DataCycleCore::Asset

        can [:read, :update, :import, :set_life_cycle, :move_content], DataCycleCore::Thing do |content|
          content.try(:external_key).blank? || DataCycleCore::Feature::Overlay.allowed?(content) || content.global_property_names.present?
        end

        # PDFs for shared links
        can :create, DataCycleCore::TextFile

        # TODO: change when migration is finished
        can :create_item, '' if TEMPLATES&.size&.positive?
        can :create, DataCycleCore::Thing do |template|
          TEMPLATES.include?(template.template_name)
        end

        can :destroy, DataCycleCore::Thing do |content|
          content&.created_by_user == user
        end
      end
    end
  end
end
