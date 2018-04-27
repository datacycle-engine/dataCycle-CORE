module DataCycleCore
  class Ability
    CONTENT_MODELS = DataCycleCore.content_tables.map { |table| "DataCycleCore::#{table.classify}".constantize }.freeze

    include CanCan::Ability

    def initialize(user, session = {})
      alias_action :update, :destroy, to: :modify
      alias_action :create, :import, :read, :update, :create_user, :search, :unlock, :validate, :validate_single_data, to: :crud

      if user
        can :show, :all

        if user.has_rank?(0)
          can [:show, :find], :object_browser

          DataCycleCore::DataLink.session_edit_links(session[:can_edit_ids]).each do |link|
            if link.is_valid? && link.item_type == 'DataCycleCore::WatchList'
              can [:update, :validate, :validate_single_data, :import], CONTENT_MODELS do |content|
                if content.try(:schema)&.dig('releasable') && DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner]).present?
                  link.item.watch_list_data_hashes.pluck(:hashable_id).include?(content.id) && content.release_id == DataCycleCore::Release.find_by(release_code: DataCycleCore.release_codes[:partner]).id
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

        if user.has_rank?(1)
          can [:read, :settings], :backend
          can [:show, :update], DataCycleCore::User, id: user.id
          can [:read, :create, :update, :destroy, :show_history], DataCycleCore::StoredFilter, user_id: user.id
          can :read, DataCycleCore::StoredFilter, system: true
          can :read, :publication
          can :read, DataCycleCore::Subscription
          can [:subscribe, :history, :history_detail], CONTENT_MODELS

          can [:read, :create, :update, :destroy], DataCycleCore::WatchList, user_id: user.id
          can [:add_item, :remove_item], DataCycleCore::WatchList do |watch_list|
            watch_list.data_links.where(permissions: 'write').none?(&:is_valid?) && watch_list.user_id == user.id
          end
        end

        if user.has_rank?(10)
          can [:read, :create, :update, :destroy], [DataCycleCore::DataLink, DataCycleCore::UserGroup]
          can [:read, :create_user, :update, :destroy, :unlock, :generate_access_token], DataCycleCore::User do |the_user|
            the_user == user || user&.role&.rank&.>(the_user&.role&.rank)
          end

          can :update_release_status, CONTENT_MODELS

          can :manage, [DataCycleCore::Classification, DataCycleCore::ClassificationTree], external_source_id: nil
          can [:read, :download], DataCycleCore::ClassificationTreeLabel
          can [:update, :download], [DataCycleCore::ClassificationTreeLabel, DataCycleCore::ClassificationAlias], external_source_id: nil, internal: false

          can :map_classifications, DataCycleCore::ClassificationAlias
          can :destroy, DataCycleCore::ClassificationTreeLabel do |c|
            c.external_source_id.nil? && !c.internal && !c.classification_aliases&.any?(&:internal) && !c.classification_aliases&.any?(&:external_source_id)
          end
          can :destroy, DataCycleCore::ClassificationAlias do |c|
            c.external_source_id.nil? && !c.internal && !c.sub_classification_alias&.any?(&:internal) && !c.sub_classification_alias&.any?(&:external_source_id)
          end

          can :crud, CONTENT_MODELS do |data_object|
            # data_object&.schema&.dig('permissions', 'read_write') != false
            data_object.try(:external_key).blank? || data_object&.schema&.dig('features', 'overlay').present?
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
          # !attribute.options['readonly']
          (
            attribute.content.try(:external_key).blank? ||
            (
              attribute.content&.schema&.dig('features', 'overlay').present? &&
              (attribute.key.scan(/\[(.*?)\]/).flatten & attribute.content.schema.dig('features', 'overlay')).size.nonzero?
            )
          )
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
