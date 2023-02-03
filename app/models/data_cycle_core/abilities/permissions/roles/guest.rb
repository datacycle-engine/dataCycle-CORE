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
            permit(
              segment(:UsersByRole).new(role),
              :create_editable_links, :auto_login,
              segment(:SubjectByConditions).new(DataCycleCore::DataLink)
            )

            permit(
              segment(:UsersByRole).new(role),
              :auto_login,
              segment(:DataLinkByReceiver).new
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

            # WatchList
            permit(
              segment(:UsersByRole).new(role),
              :copy_api_link,
              segment(:SubjectByConditions).new(DataCycleCore::WatchList, my_selection: false)
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

            # User
            permit(
              segment(:UsersByRole).new(role),
              :update,
              segment(:SubjectByUserAndConditions).new(DataCycleCore::User, :id)
            )
          end
        end
      end
    end
  end
end
