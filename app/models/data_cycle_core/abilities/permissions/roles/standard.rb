# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module Standard
          def load_standard_permissions(role = :standard)
            ###################################################################################
            ### standard
            ###################################################################################
            # DataLink
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :create_editable_links,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::DataLink)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read, :create, :update, :destroy,
              DataCycleCore::Abilities::Segments::SubjectByUserAndConditions.new(DataCycleCore::DataLink, :creator_id)
            )

            # ObjectBrowser
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :show, :find,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(:object_browser)
            )

            # UserApi
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
<<<<<<< HEAD
              :can, :login, :renew_login, :reset_password,
=======
              :can, :login, :renew_login, :reset_password, :confirm,
>>>>>>> old/develop
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(:user_api)
            )

            # Asset
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read,
              DataCycleCore::Abilities::Segments::AssetByUserAndNoContent.new
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :create_duplicate,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::Asset)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :create, :update, :destroy,
              DataCycleCore::Abilities::Segments::SubjectByUserAndConditions.new(DataCycleCore::Asset, :creator_id)
            )

            # Thing
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :create,
              DataCycleCore::Abilities::Segments::TemplateByCreatableScope.new(:all)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :print,
              DataCycleCore::Abilities::Segments::ThingByContentType.new('entity')
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can,
              :show_related,
              :show_external_connections,
              :subscribe,
              :history,
              :view_life_cycle,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::Thing)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
<<<<<<< HEAD
=======
              :can,
              :history,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::Thing::History)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
>>>>>>> old/develop
              :can, :read, :update, :import, :set_life_cycle, :move_content,
              DataCycleCore::Abilities::Segments::ContentIsEditable.new(
                [
                  :content_not_external?,
                  :content_overlay_allowed?,
                  :content_global_property_names_present?
                ]
              )
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :destroy,
              DataCycleCore::Abilities::Segments::SubjectByUserAndConditions.new(DataCycleCore::Thing, :created_by)
            )

            # StoredFilter
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :api,
              DataCycleCore::Abilities::Segments::SubjectByUserAndConditions.new(DataCycleCore::StoredFilter, :user_id, api: true)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :api,
              DataCycleCore::Abilities::Segments::StoredFilterByApiUsers.new
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read, :create, :update, :destroy, :show_history,
              DataCycleCore::Abilities::Segments::SubjectByUserAndConditions.new(DataCycleCore::StoredFilter, :user_id)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::StoredFilter, system: true)
            )

            # WatchList
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :copy_api_link,
<<<<<<< HEAD
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::WatchList)
=======
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::WatchList, my_selection: false)
>>>>>>> old/develop
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read, :create, :update, :add_item, :remove_item,
              DataCycleCore::Abilities::Segments::SubjectByUserAndConditions.new(DataCycleCore::WatchList, :user_id)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :destroy, :share, :change_owner,
              DataCycleCore::Abilities::Segments::SubjectByUserAndConditions.new(DataCycleCore::WatchList, :user_id, my_selection: false)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read, :add_item, :remove_item,
              DataCycleCore::Abilities::Segments::WatchListByGroupShares.new(my_selection: false)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read, :add_item, :remove_item,
              DataCycleCore::Abilities::Segments::WatchListByUserShares.new(my_selection: false)
            )

            # DataAttributes
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read,
              DataCycleCore::Abilities::Segments::DataAttributeAllowedForShow.new(
                [
                  :attribute_not_disabled?,
                  :overlay_attribute_visible?,
                  :attribute_not_releasable?
                ]
              )
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :edit,
              DataCycleCore::Abilities::Segments::DataAttributeAllowedForEdit.new(
                [
                  :attribute_not_included_in_publication_schedule?,
                  :attribute_not_disabled?,
                  :overlay_attribute_visible?,
                  :attribute_not_external?,
                  :attribute_tree_label_visible?
                ]
              )
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :update,
              DataCycleCore::Abilities::Segments::DataAttributeAllowedForUpdate.new(
                [
                  :attribute_not_included_in_publication_schedule?,
                  :attribute_not_disabled?,
                  :attribute_not_read_only?,
                  :overlay_attribute_visible?,
                  :attribute_not_external?,
                  :attribute_tree_label_visible?
                ]
              )
            )

            # Backend
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read, :settings,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(:backend)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :search, :classification_trees, :classification_tree, :permanent_advanced, :advanced, :publication_date,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(
                [:backend, :classification_tree, :publications, :subscriptions, :things, :collection]
              )
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :advanced_filter,
              DataCycleCore::Abilities::Segments::AdvancedFilterExceptType.new(
                [:backend, :classification_tree, :publications, :subscriptions, :things, :collection],
                [:advanced_attributes, :classification_tree_ids]
              )
            )

            # Subscription
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new([DataCycleCore::Subscription, :publication])
            )

            # User
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :update,
              DataCycleCore::Abilities::Segments::SubjectByUserAndConditions.new(DataCycleCore::User, :id)
            )

            ### Features
            # ViewMode
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, *DataCycleCore.features.dig('view_mode', 'allowed').map(&:to_sym),
              DataCycleCore::Abilities::Segments::SubjectByEnabledFeature.new(:view_mode, DataCycleCore::Feature::ViewMode)
            )
          end
        end
      end
    end
  end
end
