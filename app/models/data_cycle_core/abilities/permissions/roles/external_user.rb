# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module ExternalUser
          def load_external_user_permissions(role = :external_user)
            ###################################################################################
            ### external_user
            ###################################################################################
            # DataLink
            permit(
              segment(:UsersByRole).new(role),
              :create_editable_links,
              segment(:SubjectByConditions).new(DataCycleCore::DataLink)
            )

            # ObjectBrowser
            permit(
              segment(:UsersByRole).new(role),
              :show, :find,
              segment(:SubjectByConditions).new(:object_browser)
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

            # Thing
            permit(
              segment(:UsersByRole).new(role),
              :create,
              segment(:TemplateByCreatableScope).new('asset')
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
              :read, :create, :update, :destroy, :show_history,
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
              :read, :settings,
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
                [:advanced_attributes, :classification_tree_ids]
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
              :show, :update,
              segment(:SubjectByUserAndConditions).new(DataCycleCore::User, :id)
            )

            ### Features
            # ViewMode
            permit(
              segment(:UsersByRole).new(role),
              :tree,
              segment(:SubjectByEnabledFeature).new(:view_mode, DataCycleCore::Feature::ViewMode)
            )

            # Classification Overview
            permit(
              segment(:UsersByRole).new(role),
              :read,
              segment(:TreeLabelByVisibility).new('classification_overview')
            )
          end
        end
      end
    end
  end
end
