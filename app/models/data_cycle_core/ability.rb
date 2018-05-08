module DataCycleCore
  class Ability
    CONTENT_MODELS = DataCycleCore.content_tables.map { |object| ('DataCycleCore::' + object.singularize.classify).constantize }.freeze
    include CanCan::Ability

    def initialize(user, session = {})
      alias_action :update, :destroy, to: :modify
      alias_action :create, :import, :read, :update, :create_user, :search, :unlock, :validate, :validate_single_data, to: :crud

      if user
        can :read, :all
        cannot :manage, [DataCycleCore::WatchList, DataCycleCore::StoredFilter]
        cannot :read, :backend
        can :search, DataCycleCore::User
        can [:show, :find], :object_browser

        if user.has_rank?(0)
          can :show, DataCycleCore::WatchList

          DataCycleCore::DataLink.session_edit_links(session[:can_edit_ids]).each do |link|
            can [:update, :validate, :validate_single_data, :import], link.item_type.constantize, { id: link.item_id } if link.is_valid?
          end

          can :print, CONTENT_MODELS do |content|
            ['entity'].include?(content.schema['content_type'])
          end
        end

        if user.has_rank?(1)
          can [:read, :settings, :store_filter], :backend
          can :modify, DataCycleCore::User, id: user.id
          can :manage, DataCycleCore::WatchList, user_id: user.id
          can [:read, :create, :update, :destroy, :show_history], DataCycleCore::StoredFilter, user_id: user.id
          can :read, DataCycleCore::StoredFilter, system: true
          can :show_publications, DataCycleCore::Content
          can [:subscribe, :history, :history_detail], CONTENT_MODELS
        end

        if user.has_rank?(10)
          can :manage, DataCycleCore::DataLink
          can [:crud, :destroy], DataCycleCore::UserGroup
          can [:crud, :destroy, :generate_access_token], DataCycleCore::User do |the_user|
            user&.role&.rank&.>(the_user&.role&.rank) || the_user == user
          end

          can :update_release_status, CONTENT_MODELS

          can :manage, [DataCycleCore::Classification, DataCycleCore::ClassificationTree], external_source_id: nil
          can :download, DataCycleCore::ClassificationTreeLabel
          can [:update, :download], [DataCycleCore::ClassificationTreeLabel, DataCycleCore::ClassificationAlias], external_source_id: nil, internal: false

          can :map_classifications, DataCycleCore::ClassificationAlias

          can :destroy, DataCycleCore::ClassificationTreeLabel do |c|
            c.external_source_id.nil? && !c.internal && !c.classification_aliases&.any?(&:internal) && !c.classification_aliases&.any?(&:external_source_id)
          end

          can :destroy, DataCycleCore::ClassificationAlias do |c|
            c.external_source_id.nil? && !c.internal && !c.sub_classification_alias&.any?(&:internal) && !c.sub_classification_alias&.any?(&:external_source_id)
          end

          can :crud, CONTENT_MODELS do |data_object|
            data_object.try(:external_key).blank? || DataCycleCore::Feature::Overlay.allowed?(data_object)
          end

          can [:set_role, :set_user_groups], DataCycleCore::User do |the_user|
            !the_user.has_rank?(user.role.rank) || user == the_user
          end
          can :destroy, CONTENT_MODELS do |data_object|
            data_object.try(:external_key).blank?
          end

          can :set_life_cycle, DataCycleCore::CreativeWork

          can :manage, DataCycleCore::Asset
          can [:create_global, :create_api], DataCycleCore::StoredFilter, user_id: user.id
        end

        can :manage, :dash_board if user.has_rank?(10) && (user.email =~ /@pixelpoint\.at/ || user.email =~ /@datacycle\.at/)

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

        can :show_attribute, DataCycleCore::DataAttribute do |_attribute|
          true
        end

        unless user.email =~ /@pixelpoint\.at/ || user.email =~ /@datacycle\.at/
          cannot :modify, DataCycleCore::User do |the_user|
            the_user.has_rank?(user.role.try(:rank)) && the_user != user
          end
        end

      end
    end
  end
end
