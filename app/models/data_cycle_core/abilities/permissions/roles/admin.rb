# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module Admin
          def load_admin_permissions(role = :admin)
            ###################################################################################
            ### admin
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

            # Role
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :index,
              DataCycleCore::Abilities::Segments::RolesExcept.new(:super_admin)
            )

            # UserApi
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :login, :renew_login, :reset_password, :confirm,
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
              :merge_duplicates,
              :remove_lock,
              :translate,
              :set_life_cycle,
              :view_life_cycle,
              :move_content,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::Thing)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can,
              :subscribe,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::WatchList)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can,
              :history,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::Thing::History)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read, :update, :import,
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
              DataCycleCore::Abilities::Segments::SubjectNotExternal.new([DataCycleCore::Thing])
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
              :can, :read, :create, :update, :destroy, :show_history, :create_global, :create_api, :create_api_with_users,
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
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::WatchList, my_selection: false)
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
              :can, :read, :settings, :sortable,
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
                [:advanced_attributes]
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
              :can, :read, :create_user, :update, :destroy, :unlock, :generate_access_token, :set_role, :set_user_groups,
              DataCycleCore::Abilities::Segments::UsersExceptRoles.new(:super_admin)
            )

            # UserGroup
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read, :create, :update, :destroy,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::UserGroup)
            )

            # Download
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :download,
              DataCycleCore::Abilities::Segments::DownloadAllowedByContentAndScope.new([DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter], [:content])
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :download_zip,
              DataCycleCore::Abilities::Segments::DownloadAllowedByContentAndScope.new([DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter], [:archive, :zip])
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :download_indesign,
              DataCycleCore::Abilities::Segments::DownloadAllowedByContentAndScope.new([DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter], [:archive, :indesign])
            )

            # Report
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :index, :download_report, :download_global_report,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(:report)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :download_content_report,
              DataCycleCore::Abilities::Segments::ContentByReportGenerator.new
            )

            # Classification
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :manage,
              DataCycleCore::Abilities::Segments::SubjectNotExternal.new([DataCycleCore::Classification, DataCycleCore::ClassificationTree])
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read,
              DataCycleCore::Abilities::Segments::SubjectNotInternal.new(DataCycleCore::ClassificationTreeLabel)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :download, :create, :edit,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::ClassificationTreeLabel)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :update,
              DataCycleCore::Abilities::Segments::SubjectNotExternalAndNotInternal.new(DataCycleCore::ClassificationTreeLabel)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :create, :update,
              DataCycleCore::Abilities::Segments::SubjectNotExternalAndNotInternal.new(DataCycleCore::ClassificationAlias)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :map_classifications,
              DataCycleCore::Abilities::Segments::SubjectNotInternal.new(DataCycleCore::ClassificationAlias)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :destroy,
              DataCycleCore::Abilities::Segments::ClassificationTreeLabelAndClassificationAliasesNotExternalAndNotInternal.new
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :destroy,
              DataCycleCore::Abilities::Segments::ClassificationAliasAndChildrenNotExternalAndNotInternal.new
            )

            # Cache
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :clear, :clear_all,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(:cache)
            )

            ### Features
            # NamedVersion
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :remove_version_name,
              DataCycleCore::Abilities::Segments::SubjectByEnabledFeature.new([DataCycleCore::Thing, DataCycleCore::Thing::History], DataCycleCore::Feature::NamedVersion)
            )

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
