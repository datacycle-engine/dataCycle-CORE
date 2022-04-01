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
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :manage,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(
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
              )
            )

            # Role
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::Role)
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

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read,
              DataCycleCore::Abilities::Segments::AssetByUserGroupsForDataLink.new
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
              :update,
              :read,
              :import,
              :destroy,
              :show_admin_panel,
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
              :switch_primary_external_system,
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

            # temporary disable exif data on show view
            # add_permission(
            #   DataCycleCore::Abilities::Segments::UsersByRole.new(role),
            #   :can, :show_exif_data,
            #   DataCycleCore::Abilities::Segments::ThingByTemplateName.new('Bild')
            # )

            # StoredFilter
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read, :create, :update, :destroy, :show_history, :create_global, :create_api, :create_api_with_users, :api,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::StoredFilter)
            )

            # WatchList
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :show, :bulk_edit, :bulk_delete, :update, :change_owner,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::WatchList)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :copy_api_link,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::WatchList, my_selection: false)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read, :create, :add_item, :remove_item,
              DataCycleCore::Abilities::Segments::SubjectByUserAndConditions.new(DataCycleCore::WatchList, :user_id)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :destroy, :share,
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

            # enable to edit all attributes
            # if Rails.env.development?
            #   # DataAttributes
            #   add_permission(
            #     DataCycleCore::Abilities::Segments::UsersByRole.new(role),
            #     :can, :read,
            #     DataCycleCore::Abilities::Segments::DataAttributeAllowedForShow.new([])
            #   )
            #   add_permission(
            #     DataCycleCore::Abilities::Segments::UsersByRole.new(role),
            #     :can, :edit,
            #     DataCycleCore::Abilities::Segments::DataAttributeAllowedForEdit.new([])
            #   )
            #   add_permission(
            #     DataCycleCore::Abilities::Segments::UsersByRole.new(role),
            #     :can, :update,
            #     DataCycleCore::Abilities::Segments::DataAttributeAllowedForUpdate.new([])
            #   )
            # end

            # Backend
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :search, :classification_trees, :classification_tree, :permanent_advanced, :advanced, :publication_date,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(
                [:classification_tree, :publications, :subscriptions, :things, :collection]
              )
            )

            # Subscription
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new([DataCycleCore::Subscription, :publication])
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
              :can, :download_content_report,
              DataCycleCore::Abilities::Segments::ContentByReportGenerator.new
            )

            # Classification
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :manage,
              DataCycleCore::Abilities::Segments::SubjectNotExternal.new([DataCycleCore::Classification, DataCycleCore::ClassificationTree])
            )

            # ThingHistory
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :show, :restore_version,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::Thing::History)
            )

            ### Features
            # ViewMode
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :grid, :list, :tree, :map,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(:view_mode)
            )

            # NamedVersion
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :remove_version_name,
              DataCycleCore::Abilities::Segments::SubjectByEnabledFeature.new([DataCycleCore::Thing, DataCycleCore::Thing::History], DataCycleCore::Feature::NamedVersion)
            )
          end
        end
      end
    end
  end
end
