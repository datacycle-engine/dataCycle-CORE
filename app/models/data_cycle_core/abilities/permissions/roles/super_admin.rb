# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module SuperAdmin
          def load_super_admin_permissions(role = :super_admin)
            ###################################################################################
            ### super_admin
            ###################################################################################
            # DataLink
            # ObjectBrowser
            # UserApi
            # User
            # UserGroup
            # Report
            # Cache
            permit_user(role, :manage, SubjectByConditions: [
                          [
                            :dash_board,
                            :backend,
                            :user_api,
                            :object_browser,
                            :cache,
                            :report,
                            DataCycleCore::ClassificationTreeLabel,
                            DataCycleCore::ClassificationAlias,
                            DataCycleCore::User,
                            DataCycleCore::UserGroup,
                            DataCycleCore::DataLink
                          ]
                        ])

            # Role
            permit_user(role, :read, SubjectByConditions: [DataCycleCore::Role])

            # Asset
            permit_user(role, :read, :AssetByUserAndNoContent)
            permit_user(role, :create_duplicate, SubjectByConditions: [DataCycleCore::Asset])
            permit_user(role, :create, :update, :destroy, SubjectByUserAndConditions: [DataCycleCore::Asset, :creator_id])
            permit_user(role, :read, :AssetByUserGroupsForDataLink)

            # Thing
            permit_user(role, :create, TemplateByCreatableScope: [:all])
            permit_user(role, :print, ThingByContentType: ['entity'])
            permit_user(role, :update, :read, :import, :destroy, :show_admin_panel, :show_related, :show_external_connections, :subscribe, :history, :merge_duplicates, :remove_lock, :translate, :set_life_cycle, :view_life_cycle, :move_content, :switch_primary_external_system, :create_external_connection, :remove_external_connection, SubjectByConditions: [DataCycleCore::Thing])
            permit_user(role, :subscribe, SubjectByConditions: [DataCycleCore::WatchList])
            permit_user(role, :history, SubjectByConditions: [DataCycleCore::Thing::History])

            # StoredFilter
            permit_user(role, :read, :create, :update, :destroy, :show_history, :create_global, :create_api, :create_api_with_users, :api, SubjectByConditions: [DataCycleCore::StoredFilter])

            # WatchList
            permit_user(role, :show, :bulk_edit, :bulk_delete, :update, :change_owner, :create_api, SubjectByConditions: [DataCycleCore::WatchList])
            permit_user(role, :read, :create, :add_item, :remove_item, SubjectByUserAndConditions: [DataCycleCore::WatchList, :user_id])
            permit_user(role, :destroy, :share, SubjectByUserAndConditions: [DataCycleCore::WatchList, :user_id, my_selection: false])
            permit_user(role, :read, :add_item, :remove_item, WatchListByGroupShares: [my_selection: false])
            permit_user(role, :read, :add_item, :remove_item, WatchListByUserShares: [my_selection: false])

            # DataAttributes
            permit_user(role, :read, DataAttributeAllowedForShow: [
                          [
                            :attribute_not_disabled?,
                            :overlay_attribute_visible?,
                            :attribute_not_releasable?
                          ]
                        ])

            permit_user(role, :edit, DataAttributeAllowedForEdit: [
                          [
                            :attribute_not_included_in_publication_schedule?,
                            :attribute_not_disabled?,
                            :overlay_attribute_visible?,
                            :attribute_not_external?,
                            :attribute_tree_label_visible?
                          ]
                        ])

            permit_user(role, :update, DataAttributeAllowedForUpdate: [
                          [
                            :attribute_not_included_in_publication_schedule?,
                            :attribute_not_disabled?,
                            :attribute_not_read_only?,
                            :overlay_attribute_visible?,
                            :attribute_not_external?,
                            :attribute_tree_label_visible?
                          ]
                        ])

            # enable to edit all attributes
            # if Rails.env.development?
            #   # DataAttributes
            #   permit_user(
            #     role,
            #     :read,
            #     DataAttributeAllowedForShow: [[]]
            #   )
            #   permit_user(
            #     role,
            #     :edit,
            #     DataAttributeAllowedForEdit: [[]]
            #   )
            #   permit_user(
            #     role,
            #     :update,
            #     DataAttributeAllowedForUpdate: [[]]
            #   )
            # end

            # Backend
            permit_user(role, :search, :classification_trees, :classification_tree, :permanent_advanced, :advanced, :publication_date, SubjectByConditions: [[:backend, :classification_tree, :publications, :subscriptions, :things, :collection]])
            permit_user(role, :advanced_filter, AdvancedFilterExceptType: [
                          [:backend, :classification_tree, :publications, :subscriptions, :things, :collection],
                          []
                        ])

            # Subscription
            permit_user(role, :read, SubjectByConditions: [[DataCycleCore::Subscription, :publication]])

            # Download
            permit_user(role, :download, DownloadAllowedByContentAndScope: [[DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter], [:content]])
            permit_user(role, :download_zip, DownloadAllowedByContentAndScope: [[DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter], [:archive, :zip]])
            permit_user(role, :download_indesign, DownloadAllowedByContentAndScope: [[DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter], [:archive, :indesign]])

            # Report
            permit_user(role, :download_content_report, :ContentByReportGenerator)

            # Classification
            permit_user(role, :manage, SubjectNotExternal: [[DataCycleCore::Classification, DataCycleCore::ClassificationTree]])

            # ThingHistory
            permit_user(role, :show, :restore_version, SubjectByConditions: [DataCycleCore::Thing::History])

            ### Features
            # ViewMode
            permit_user(role, :grid, :list, :tree, :map, SubjectByConditions: [:view_mode])

            # NamedVersion
            permit_user(role, :remove_version_name, SubjectByEnabledFeature: [[DataCycleCore::Thing, DataCycleCore::Thing::History], DataCycleCore::Feature::NamedVersion])

            # auto_translate
            permit_user(role, :create, :destroy, SubjectByConditions: :auto_translate)

            permit_user(role, :create, SubjectByConditions: [DataCycleCore::ExternalSystem])
          end
        end
      end
    end
  end
end
