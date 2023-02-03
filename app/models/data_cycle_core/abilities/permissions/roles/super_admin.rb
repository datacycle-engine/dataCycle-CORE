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
            permit(
              segment(:UsersByRole).new(role),
              :manage,
              segment(:SubjectByConditions).new(
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
            permit(
              segment(:UsersByRole).new(role),
              :read,
              segment(:SubjectByConditions).new(DataCycleCore::Role)
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

            permit(
              segment(:UsersByRole).new(role),
              :read,
              segment(:AssetByUserGroupsForDataLink).new
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
              :create_external_connection,
              :remove_external_connection,
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

            # temporary disable exif data on show view
            # permit(
            #   segment(:UsersByRole).new(role),
            #   :show_exif_data,
            #   segment(:ThingByTemplateName).new('Bild')
            # )

            # StoredFilter
            permit(
              segment(:UsersByRole).new(role),
              :read, :create, :update, :destroy, :show_history, :create_global, :create_api, :create_api_with_users, :api,
              segment(:SubjectByConditions).new(DataCycleCore::StoredFilter)
            )

            # WatchList
            permit(
              segment(:UsersByRole).new(role),
              :show, :bulk_edit, :bulk_delete, :update, :change_owner,
              segment(:SubjectByConditions).new(DataCycleCore::WatchList)
            )

            permit(
              segment(:UsersByRole).new(role),
              :copy_api_link,
              segment(:SubjectByConditions).new(DataCycleCore::WatchList, my_selection: false)
            )

            permit(
              segment(:UsersByRole).new(role),
              :read, :create, :add_item, :remove_item,
              segment(:SubjectByUserAndConditions).new(DataCycleCore::WatchList, :user_id)
            )

            permit(
              segment(:UsersByRole).new(role),
              :destroy, :share,
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

            # enable to edit all attributes
            # if Rails.env.development?
            #   # DataAttributes
            #   permit(
            #     segment(:UsersByRole).new(role),
            #     :read,
            #     segment(:DataAttributeAllowedForShow).new([])
            #   )
            #   permit(
            #     segment(:UsersByRole).new(role),
            #     :edit,
            #     segment(:DataAttributeAllowedForEdit).new([])
            #   )
            #   permit(
            #     segment(:UsersByRole).new(role),
            #     :update,
            #     segment(:DataAttributeAllowedForUpdate).new([])
            #   )
            # end

            # Backend
            permit(
              segment(:UsersByRole).new(role),
              :search, :classification_trees, :classification_tree, :permanent_advanced, :advanced, :publication_date,
              segment(:SubjectByConditions).new(
                [:classification_tree, :publications, :subscriptions, :things, :collection]
              )
            )

            # Subscription
            permit(
              segment(:UsersByRole).new(role),
              :read,
              segment(:SubjectByConditions).new([DataCycleCore::Subscription, :publication])
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
              :download_content_report,
              segment(:ContentByReportGenerator).new
            )

            # Classification
            permit(
              segment(:UsersByRole).new(role),
              :manage,
              segment(:SubjectNotExternal).new([DataCycleCore::Classification, DataCycleCore::ClassificationTree])
            )

            # ThingHistory
            permit(
              segment(:UsersByRole).new(role),
              :show, :restore_version,
              segment(:SubjectByConditions).new(DataCycleCore::Thing::History)
            )

            ### Features
            # ViewMode
            permit(
              segment(:UsersByRole).new(role),
              :grid, :list, :tree, :map,
              segment(:SubjectByConditions).new(:view_mode)
            )

            # NamedVersion
            permit(
              segment(:UsersByRole).new(role),
              :remove_version_name,
              segment(:SubjectByEnabledFeature).new([DataCycleCore::Thing, DataCycleCore::Thing::History], DataCycleCore::Feature::NamedVersion)
            )
          end
        end
      end
    end
  end
end
