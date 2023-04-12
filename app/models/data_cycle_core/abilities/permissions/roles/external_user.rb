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
            permit_user(role, :create_editable_links, SubjectByConditions: [DataCycleCore::DataLink])

            # ObjectBrowser
            permit_user(role, :show, :find, SubjectByConditions: [:object_browser])

            # UserApi
            permit_user(role, :login, :renew_login, :reset_password, :confirm, SubjectByConditions: [:user_api])

            # Asset
            permit_user(role, :read, :AssetByUserAndNoContent)
            permit_user(role, :create_duplicate, SubjectByConditions: [DataCycleCore::Asset])

            # Thing
            permit_user(role, :create, TemplateByCreatableScope: ['asset'])
            permit_user(role, :print, ThingByContentType: ['entity'])

            permit_user(role, :show_related, :show_external_connections, :subscribe, :history, SubjectByConditions: [DataCycleCore::Thing])

            permit_user(role, :subscribe, SubjectByConditions: [DataCycleCore::WatchList])

            permit_user(role, :history, SubjectByConditions: [DataCycleCore::Thing::History])

            # StoredFilter
            permit_user(role, :api, SubjectByUserAndConditions: [DataCycleCore::StoredFilter, :user_id, api: true])
            permit_user(role, :api, :StoredFilterByApiUsers)
            permit_user(role, :read, :create, :update, :destroy, :show_history, SubjectByUserAndConditions: [DataCycleCore::StoredFilter, :user_id])
            permit_user(role, :read, SubjectByConditions: [DataCycleCore::StoredFilter, system: true])

            # WatchList
            permit_user(role, :read, :create, :update, :add_item, :remove_item, SubjectByUserAndConditions: [DataCycleCore::WatchList, :user_id])

            permit_user(role, :destroy, :share, :change_owner, SubjectByUserAndConditions: [DataCycleCore::WatchList, :user_id, my_selection: false])
            permit_user(role, :read, :add_item, :remove_item, WatchListByGroupShares: [my_selection: false])
            permit_user(role, :read, :add_item, :remove_item, WatchListByUserShares: [my_selection: false])

            # DataAttributes
            permit_user(role, :read,
                        DataAttributeAllowedForShow: [
                          [
                            :attribute_not_disabled?,
                            :overlay_attribute_visible?,
                            :attribute_not_releasable?
                          ]
                        ])

            permit_user(role, :edit,
                        DataAttributeAllowedForEdit: [
                          [
                            :attribute_not_included_in_publication_schedule?,
                            :attribute_not_disabled?,
                            :overlay_attribute_visible?,
                            :attribute_not_external?,
                            :attribute_tree_label_visible?
                          ]
                        ])

            permit_user(role, :update,
                        DataAttributeAllowedForUpdate: [
                          [
                            :attribute_not_included_in_publication_schedule?,
                            :attribute_not_disabled?,
                            :attribute_not_read_only?,
                            :overlay_attribute_visible?,
                            :attribute_not_external?,
                            :attribute_tree_label_visible?
                          ]
                        ])

            # Backend
            permit_user(role, :read, :settings, SubjectByConditions: [:backend])

            permit_user(role,
                        :search, :classification_trees, :classification_tree, :permanent_advanced, :advanced, :publication_date,
                        SubjectByConditions: [
                          [:backend, :classification_tree, :publications, :subscriptions, :things, :collection]
                        ])

            permit_user(role, :advanced_filter,
                        AdvancedFilterExceptType: [
                          [:backend, :classification_tree, :publications, :subscriptions, :things, :collection],
                          [:advanced_attributes, :classification_tree_ids]
                        ])

            # Subscription
            permit_user(role, :read, SubjectByConditions: [[DataCycleCore::Subscription, :publication]])

            # User
            permit_user(role, :show, :update, SubjectByUserAndConditions: [DataCycleCore::User, :id])

            ### Features
            # ViewMode
            permit_user(role, :tree, SubjectByEnabledFeature: [:view_mode, DataCycleCore::Feature::ViewMode])

            # Classification Overview
            permit_user(role, :read, TreeLabelByVisibility: ['classification_overview'])
          end
        end
      end
    end
  end
end
