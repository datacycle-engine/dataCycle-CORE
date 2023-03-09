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
            permit_user(role, :copy_api_link, SubjectByConditions: [DataCycleCore::WatchList, my_selection: false])

            ### Features
            # ViewMode
            permit_user(role, :grid, SubjectByEnabledFeature: [:view_mode, DataCycleCore::Feature::ViewMode])
          end
        end
      end
    end
  end
end
