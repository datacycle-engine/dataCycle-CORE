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
            permit(
              segment(:UsersByRole).new(role),
              :show,
              segment(:SubjectByConditions).new(
                [
                  DataCycleCore::Thing,
                  DataCycleCore::WatchList,
                  DataCycleCore::StoredFilter
                ]
              )
            )

            # DataLink for things, watch_lists
            permit(
              segment(:UsersByRole).new(role),
              :update, :import,
              segment(:ThingByDataLink).new
            )
            # DataLink for stored_filter
            permit(
              segment(:UsersByRole).new(role),
              :read, :search, :classification_trees, :classification_tree, :permanent_advanced, :advanced,
              segment(:StoredFilterByDataLink).new('fulltext_search')
            )

            ### Features
            # ViewMode
            permit(
              segment(:UsersByRole).new(role),
              :grid,
              segment(:SubjectByEnabledFeature).new(:view_mode, DataCycleCore::Feature::ViewMode)
            )
          end
        end
      end
    end
  end
end
