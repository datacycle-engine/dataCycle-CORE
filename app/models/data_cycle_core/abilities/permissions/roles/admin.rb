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
            permit_user(role, :create_editable_links, SubjectByConditions: DataCycleCore::DataLink)
            permit_user(role, :read, :create, :update, :destroy, SubjectByUserAndConditions: [DataCycleCore::DataLink, :creator_id])

            # ObjectBrowser
            permit_user(role, :show, :find, SubjectByConditions: :object_browser)

            # Role
            permit_user(role, :index, RolesExcept: :super_admin)

            # UserApi
            permit_user(role, :login, :renew_login, :reset_password, :confirm, SubjectByConditions: :user_api)

            # Asset
            permit_user(role, :read, :AssetByUserAndNoContent)
            permit_user(role, :create_duplicate, SubjectByConditions: DataCycleCore::Asset)
            permit_user(role, :create, :update, :destroy, SubjectByUserAndConditions: [DataCycleCore::Asset, :creator_id])

            # Thing
            permit_user(role, :create, TemplateByCreatableScope: :all)
            permit_user(role, :print, ThingByContentType: 'entity')
            permit_user(role, :show_related, :show_external_connections, :subscribe, :history, :merge_duplicates, :remove_lock, :translate, :set_life_cycle, :view_life_cycle, :move_content, SubjectByConditions: DataCycleCore::Thing)
            permit_user(role, :subscribe, SubjectByConditions: DataCycleCore::WatchList)
            permit_user(role, :history, SubjectByConditions: DataCycleCore::Thing::History)
            permit_user(role, :read, :update, :import, ContentIsEditable: [
                          :content_not_external?,
                          :content_overlay_allowed?,
                          :content_global_property_names_present?
                        ])

            permit_user(role, :destroy, SubjectNotExternal: DataCycleCore::Thing)

            # StoredFilter
            permit_user(role, :api, SubjectByUserAndConditions: [DataCycleCore::StoredFilter, :user_id, api: true])
            permit_user(role, :api, :StoredFilterByApiUsers)
            permit_user(role, :read, :create, :update, :destroy, :show_history, :create_global, :create_api, :create_api_with_users, SubjectByUserAndConditions: [DataCycleCore::StoredFilter, :user_id])
            permit_user(role, :read, SubjectByConditions: [DataCycleCore::StoredFilter, system: true])

            # WatchList
            permit_user(role, :read, :create, :update, :add_item, :remove_item, SubjectByUserAndConditions: [DataCycleCore::WatchList, :user_id])
            permit_user(role, :destroy, :share, :change_owner, SubjectByUserAndConditions: [DataCycleCore::WatchList, :user_id, my_selection: false])
            permit_user(role, :read, :add_item, :remove_item, WatchListByGroupShares: [my_selection: false])
            permit_user(role, :read, :add_item, :remove_item, WatchListByUserShares: [my_selection: false])

            # DataAttributes
            permit_user(role, :read, DataAttributeAllowedForShow: [[
                          :attribute_not_disabled?,
                          :overlay_attribute_visible?,
                          :attribute_not_releasable?
                        ]])

            permit_user(role, :edit, DataAttributeAllowedForEdit: [[
                          :attribute_not_included_in_publication_schedule?,
                          :attribute_not_disabled?,
                          :overlay_attribute_visible?,
                          :attribute_not_external?,
                          :attribute_tree_label_visible?
                        ]])

            permit_user(role, :update, DataAttributeAllowedForUpdate: [[
                          :attribute_not_included_in_publication_schedule?,
                          :attribute_not_disabled?,
                          :attribute_not_read_only?,
                          :overlay_attribute_visible?,
                          :attribute_not_external?,
                          :attribute_tree_label_visible?
                        ]])

            # Backend
            permit_user(role, :read, :settings, :sortable, SubjectByConditions: :backend)
            permit_user(role, :search, :classification_trees, :classification_tree, :permanent_advanced, :advanced, :publication_date, SubjectByConditions: [[:backend, :classification_tree, :publications, :subscriptions, :things, :collection]])
            permit_user(role, :advanced_filter, AdvancedFilterExceptType: [
                          [:backend, :classification_tree, :publications, :subscriptions, :things, :collection],
                          [:advanced_attributes]
                        ])

            # Subscription
            permit_user(role, :read, SubjectByConditions: [[DataCycleCore::Subscription, :publication]])

            # User
            permit_user(role, :read, :create_user, :update, :destroy, :lock, :unlock, :generate_access_token, :set_role, :set_user_groups, UsersExceptRoles: :super_admin)

            # UserGroup
            permit_user(role, :read, :create, :update, :destroy, SubjectByConditions: DataCycleCore::UserGroup)

            # Download
            permit_user(role, :download, DownloadAllowedByContentAndScope: [
                          [DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter],
                          [:content]
                        ])
            permit_user(role, :download_zip, DownloadAllowedByContentAndScope: [
                          [DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter],
                          [:archive, :zip]
                        ])
            permit_user(role, :download_indesign, DownloadAllowedByContentAndScope: [
                          [DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter],
                          [:archive, :indesign]
                        ])

            # Report
            permit_user(role, :index, :download_report, :download_global_report, SubjectByConditions: :report)
            permit_user(role, :download_content_report, :ContentByReportGenerator)

            # Classification
            permit_user(role, :manage, SubjectNotExternal: [DataCycleCore::Classification, DataCycleCore::ClassificationTree])
            permit_user(role, :read, TreeLabelByVisibility: ['classification_overview', 'classification_administration'])
            permit_user(role, :download, :create, :edit, SubjectByConditions: DataCycleCore::ClassificationTreeLabel)
            permit_user(role, :update, SubjectNotExternal: DataCycleCore::ClassificationTreeLabel)
            permit_user(role, :create, :update, SubjectNotExternalAndNotInternal: DataCycleCore::ClassificationAlias)
            permit_user(role, :map_classifications, :set_color, SubjectNotInternal: DataCycleCore::ClassificationAlias)
            permit_user(role, :destroy, :ClassificationTreeLabelAndClassificationAliasesNotExternalAndNotInternal)
            permit_user(role, :destroy, :ClassificationAliasAndChildrenNotExternalAndNotInternal)

            # Cache
            permit_user(role, :clear, :clear_all, SubjectByConditions: :cache)

            ### Features
            # NamedVersion
            permit_user(role, :remove_version_name, SubjectByEnabledFeature: [
                          [DataCycleCore::Thing, DataCycleCore::Thing::History],
                          DataCycleCore::Feature::NamedVersion
                        ])

            # ViewMode
            permit_user(role, *DataCycleCore.features.dig('view_mode', 'allowed').map(&:to_sym), SubjectByEnabledFeature: [:view_mode, DataCycleCore::Feature::ViewMode])

            # auto_translate
            permit_user(role, :create, :destroy, SubjectByConditions: :auto_translate)
          end
        end
      end
    end
  end
end
