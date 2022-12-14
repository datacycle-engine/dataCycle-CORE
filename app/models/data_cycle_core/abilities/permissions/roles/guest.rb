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
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :create_editable_links, :auto_login,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::DataLink)
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :auto_login,
              DataCycleCore::Abilities::Segments::DataLinkByReceiver.new
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
              :can, :login, :renew_login, :reset_password, :confirm,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(:user_api)
            )

            # Asset
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :read,
              DataCycleCore::Abilities::Segments::AssetByUserAndNoContent.new
            )

            # Thing
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :create,
              DataCycleCore::Abilities::Segments::TemplateByCreatableScope.new('asset')
            )

            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :print,
              DataCycleCore::Abilities::Segments::ThingByContentType.new('entity')
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

            # WatchList
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :copy_api_link,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(DataCycleCore::WatchList, my_selection: false)
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

            # User
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :update,
              DataCycleCore::Abilities::Segments::SubjectByUserAndConditions.new(DataCycleCore::User, :id)
            )
          end
        end
      end
    end
  end
end
