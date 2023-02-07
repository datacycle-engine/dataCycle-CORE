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
            permit(
              segment(:UsersByRole).new(role),
              :create_editable_links,
              segment(:SubjectByConditions).new(DataCycleCore::DataLink)
            )

            permit(
              segment(:UsersByRole).new(role),
              :read, :create, :update, :destroy,
              segment(:SubjectByUserAndConditions).new(DataCycleCore::DataLink, :creator_id)
            )

            # ObjectBrowser
            permit(
              segment(:UsersByRole).new(role),
              :show, :find,
              segment(:SubjectByConditions).new(:object_browser)
            )

            # Role
            permit(
              segment(:UsersByRole).new(role),
              :index,
              segment(:RolesExcept).new(:super_admin)
            )

            # UserApi
            permit(
              segment(:UsersByRole).new(role),
              :login, :renew_login, :reset_password, :confirm,
              segment(:SubjectByConditions).new(:user_api)
            )

            # Asset
            permit(
              segment(:UsersByRole).new(role),
              :read,
              segment(:AssetByUserAndNoContent).new
            )

            permit(
              segment(:UsersByRole).new(role),
              :create_duplicate,
              segment(:SubjectByConditions).new(DataCycleCore::Asset)
            )

            permit(
              segment(:UsersByRole).new(role),
              :create, :update, :destroy,
              segment(:SubjectByUserAndConditions).new(DataCycleCore::Asset, :creator_id)
            )

            # Thing
            permit(
              segment(:UsersByRole).new(role),
              :create,
              segment(:TemplateByCreatableScope).new(:all)
            )

            permit(
              segment(:UsersByRole).new(role),
              :print,
              segment(:ThingByContentType).new('entity')
            )

            permit(
              segment(:UsersByRole).new(role),
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
              segment(:SubjectByConditions).new(DataCycleCore::Thing)
            )

            permit(
              segment(:UsersByRole).new(role),
              :subscribe,
              segment(:SubjectByConditions).new(DataCycleCore::WatchList)
            )

            permit(
              segment(:UsersByRole).new(role),
              :history,
              segment(:SubjectByConditions).new(DataCycleCore::Thing::History)
            )

            permit(
              segment(:UsersByRole).new(role),
              :read, :update, :import,
              segment(:ContentIsEditable).new(
                [
                  :content_not_external?,
                  :content_overlay_allowed?,
                  :content_global_property_names_present?
                ]
              )
            )

            permit(
              segment(:UsersByRole).new(role),
              :destroy,
              segment(:SubjectNotExternal).new([DataCycleCore::Thing])
            )

            # StoredFilter
            permit(
              segment(:UsersByRole).new(role),
              :api,
              segment(:SubjectByUserAndConditions).new(DataCycleCore::StoredFilter, :user_id, api: true)
            )

            permit(
              segment(:UsersByRole).new(role),
              :api,
              segment(:StoredFilterByApiUsers).new
            )

            permit(
              segment(:UsersByRole).new(role),
              :read, :create, :update, :destroy, :show_history, :create_global, :create_api, :create_api_with_users,
              segment(:SubjectByUserAndConditions).new(DataCycleCore::StoredFilter, :user_id)
            )

            permit(
              segment(:UsersByRole).new(role),
              :read,
              segment(:SubjectByConditions).new(DataCycleCore::StoredFilter, system: true)
            )

            # WatchList
            permit(
              segment(:UsersByRole).new(role),
              :copy_api_link,
              segment(:SubjectByConditions).new(DataCycleCore::WatchList, my_selection: false)
            )

            permit(
              segment(:UsersByRole).new(role),
              :read, :create, :update, :add_item, :remove_item,
              segment(:SubjectByUserAndConditions).new(DataCycleCore::WatchList, :user_id)
            )

            permit(
              segment(:UsersByRole).new(role),
              :destroy, :share, :change_owner,
              segment(:SubjectByUserAndConditions).new(DataCycleCore::WatchList, :user_id, my_selection: false)
            )

            permit(
              segment(:UsersByRole).new(role),
              :read, :add_item, :remove_item,
              segment(:WatchListByGroupShares).new(my_selection: false)
            )

            permit(
              segment(:UsersByRole).new(role),
              :read, :add_item, :remove_item,
              segment(:WatchListByUserShares).new(my_selection: false)
            )

            # DataAttributes
            permit(
              segment(:UsersByRole).new(role),
              :read,
              segment(:DataAttributeAllowedForShow).new(
                [
                  :attribute_not_disabled?,
                  :overlay_attribute_visible?,
                  :attribute_not_releasable?
                ]
              )
            )

            permit(
              segment(:UsersByRole).new(role),
              :edit,
              segment(:DataAttributeAllowedForEdit).new(
                [
                  :attribute_not_included_in_publication_schedule?,
                  :attribute_not_disabled?,
                  :overlay_attribute_visible?,
                  :attribute_not_external?,
                  :attribute_tree_label_visible?
                ]
              )
            )

            permit(
              segment(:UsersByRole).new(role),
              :update,
              segment(:DataAttributeAllowedForUpdate).new(
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
            permit(
              segment(:UsersByRole).new(role),
              :read, :settings, :sortable,
              segment(:SubjectByConditions).new(:backend)
            )

            permit(
              segment(:UsersByRole).new(role),
              :search, :classification_trees, :classification_tree, :permanent_advanced, :advanced, :publication_date,
              segment(:SubjectByConditions).new(
                [:backend, :classification_tree, :publications, :subscriptions, :things, :collection]
              )
            )

            permit(
              segment(:UsersByRole).new(role),
              :advanced_filter,
              segment(:AdvancedFilterExceptType).new(
                [:backend, :classification_tree, :publications, :subscriptions, :things, :collection],
                [:advanced_attributes]
              )
            )

            # Subscription
            permit(
              segment(:UsersByRole).new(role),
              :read,
              segment(:SubjectByConditions).new([DataCycleCore::Subscription, :publication])
            )

            # User
            permit(
              segment(:UsersByRole).new(role),
              :read, :create_user, :update, :destroy, :unlock, :generate_access_token, :set_role, :set_user_groups,
              segment(:UsersExceptRoles).new(:super_admin)
            )

            # UserGroup
            permit(
              segment(:UsersByRole).new(role),
              :read, :create, :update, :destroy,
              segment(:SubjectByConditions).new(DataCycleCore::UserGroup)
            )

            # Download
            permit(
              segment(:UsersByRole).new(role),
              :download,
              segment(:DownloadAllowedByContentAndScope).new([DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter], [:content])
            )

            permit(
              segment(:UsersByRole).new(role),
              :download_zip,
              segment(:DownloadAllowedByContentAndScope).new([DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter], [:archive, :zip])
            )

            permit(
              segment(:UsersByRole).new(role),
              :download_indesign,
              segment(:DownloadAllowedByContentAndScope).new([DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter], [:archive, :indesign])
            )

            # Report
            permit(
              segment(:UsersByRole).new(role),
              :index, :download_report, :download_global_report,
              segment(:SubjectByConditions).new(:report)
            )

            permit(
              segment(:UsersByRole).new(role),
              :download_content_report,
              segment(:ContentByReportGenerator).new
            )

            # Classification
            permit(
              segment(:UsersByRole).new(role),
              :manage,
              segment(:SubjectNotExternal).new([DataCycleCore::Classification, DataCycleCore::ClassificationTree])
            )

            permit(
              segment(:UsersByRole).new(role),
              :read,
              segment(:TreeLabelByVisibility).new(['classification_overview', 'classification_administration'])
            )

            permit(
              segment(:UsersByRole).new(role),
              :download, :create, :edit,
              segment(:SubjectByConditions).new(DataCycleCore::ClassificationTreeLabel)
            )

            permit(
              segment(:UsersByRole).new(role),
              :update,
              segment(:SubjectNotExternal).new(DataCycleCore::ClassificationTreeLabel)
            )

            permit(
              segment(:UsersByRole).new(role),
              :create, :update,
              segment(:SubjectNotExternalAndNotInternal).new(DataCycleCore::ClassificationAlias)
            )

            permit(
              segment(:UsersByRole).new(role),
              :map_classifications,
              segment(:SubjectNotInternal).new(DataCycleCore::ClassificationAlias)
            )

            permit(
              segment(:UsersByRole).new(role),
              :destroy,
              segment(:ClassificationTreeLabelAndClassificationAliasesNotExternalAndNotInternal).new
            )

            permit(
              segment(:UsersByRole).new(role),
              :destroy,
              segment(:ClassificationAliasAndChildrenNotExternalAndNotInternal).new
            )

            # Cache
            permit(
              segment(:UsersByRole).new(role),
              :clear, :clear_all,
              segment(:SubjectByConditions).new(:cache)
            )

            ### Features
            # NamedVersion
            permit(
              segment(:UsersByRole).new(role),
              :remove_version_name,
              segment(:SubjectByEnabledFeature).new([DataCycleCore::Thing, DataCycleCore::Thing::History], DataCycleCore::Feature::NamedVersion)
            )

            # ViewMode
            permit(
              segment(:UsersByRole).new(role),
              *DataCycleCore.features.dig('view_mode', 'allowed').map(&:to_sym),
              segment(:SubjectByEnabledFeature).new(:view_mode, DataCycleCore::Feature::ViewMode)
            )
          end
        end
      end
    end
  end
end
