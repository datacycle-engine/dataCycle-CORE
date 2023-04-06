# frozen_string_literal: true

module DataCycleCore
  module Abilities
    module Permissions
      module Roles
        module Common
          def load_common_permissions(role = :all)
            ###################################################################################
            ### ALL USERS
            ###################################################################################
            # Thing
            # WatchList
            # StoredFilter
            permit_user(role, :show, SubjectByConditions: [[DataCycleCore::Thing, DataCycleCore::WatchList, DataCycleCore::StoredFilter]])

            # DataLink for things, watch_lists
            permit_user(role, :update, :import, :ThingByDataLink)

            # DataLink for stored_filter
            permit_user(role, :read, :search, :classification_trees, :classification_tree, :permanent_advanced, :advanced, StoredFilterByDataLink: 'fulltext_search')

            # WatchList
            permit_user(role, :api, :copy_api_link, :WatchListByApi)
            permit_user(role, :create_api, SubjectByUserAndConditions: [DataCycleCore::WatchList, :user_id, my_selection: false])

            ### Features
            # ViewMode
            permit_user(role, :grid, SubjectByEnabledFeature: [:view_mode, DataCycleCore::Feature::ViewMode])

            # User Filters
            permit_user(role, :search, :user_dropdown, :user_advanced, :sortable, SubjectByConditions: :users)
            permit_user(role, :search, SubjectByConditions: :user_groups)
          end
        end
      end
    end
  end
end
