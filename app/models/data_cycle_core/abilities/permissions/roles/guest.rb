# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module Guest
          def load_guest_permissions(role = :guest)
            ###################################################################################
            ### guest
            ###################################################################################
            # DataLink
            permit_user(role, :create_editable_links, :auto_login, SubjectByConditions: [DataCycleCore::DataLink])
            permit_user(role, :auto_login, :DataLinkByReceiver)

            # ObjectBrowser
            permit_user(role, :show, :find, SubjectByConditions: [:object_browser])

            # UserApi
            permit_user(role, :login, :renew_login, :reset_password, :confirm, SubjectByConditions: [:user_api])

            # Asset
            permit_user(role, :read, :AssetByUserAndNoContent)

            # Thing
            permit_user(role, :create, TemplateByCreatableScope: ['asset'])
            permit_user(role, :print, ThingByContentType: ['entity'])

            # StoredFilter
            permit_user(role, :api, SubjectByUserAndConditions: [DataCycleCore::StoredFilter, :user_id, api: true])
            permit_user(role, :api, :StoredFilterByApiUsers)

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

            # User
            permit_user(role, :show, :update, SubjectByUserAndConditions: [DataCycleCore::User, :id])
          end
        end
      end
    end
  end
end
