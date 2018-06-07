# frozen_string_literal: true

module DataCycleCore
  module Abilities
    class Rank0Ability
      CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze
      include CanCan::Ability

      def initialize(_user, session = {})
        can [:show, :find], :object_browser

        can :edit, DataCycleCore::DataAttribute do |attribute|
          if DataCycleCore::Feature::PublicationSchedule.allowed?(attribute.content)

            !(
              (attribute.key =~ Regexp.union(*DataCycleCore.features.dig(:publication_schedule, :classification_keys))) &&
              !DataCycleCore::Feature::PublicationSchedule.includes_attribute_key(attribute.content, attribute.key)
            )

          else
            (
              attribute.content.try(:external_key).blank? ||
              (
                DataCycleCore::Feature::Overlay.allowed?(attribute.content) &&
                DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)
              )
            )
          end
        end

        cannot :show, DataCycleCore::DataAttribute do |attribute|
          attribute.definition.dig('ui', attribute.scope.to_s, 'disabled') == true ||
            (
              !DataCycleCore::Feature::Overlay.allowed?(attribute.content) &&
              DataCycleCore::Feature::Overlay.includes_attribute_key(attribute.content, attribute.key)
            )
        end

        DataCycleCore::DataLink.session_edit_links(session[:can_edit_ids]).each do |link|
          if link.is_valid? && link.item_type == 'DataCycleCore::WatchList'
            can [:update, :validate, :validate_single_data, :import], CONTENT_MODELS do |content|
              if DataCycleCore::Feature::Releasable.allowed?(content) && DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner]).present?
                link.item.watch_list_data_hashes.pluck(:hashable_id).include?(content.id) && content.release_id == DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner])&.id
              else
                link.item.watch_list_data_hashes.pluck(:hashable_id).include?(content.id)
              end
            end
          elsif link.is_valid?
            can [:update, :validate, :validate_single_data, :import], link.item_type.constantize, id: link.item_id
          end
        end

        can :print, CONTENT_MODELS do |content|
          ['entity'].include?(content.schema['content_type'])
        end
      end
    end
  end
end
