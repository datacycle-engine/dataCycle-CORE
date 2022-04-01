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
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :show,
              DataCycleCore::Abilities::Segments::SubjectByConditions.new(
                [
                  DataCycleCore::Thing,
                  DataCycleCore::WatchList,
                  DataCycleCore::StoredFilter
                ]
              )
            )

            # DataLink
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :update, :import,
              DataCycleCore::Abilities::Segments::ThingByDataLink.new
            )

            ### Features
            # ViewMode
            add_permission(
              DataCycleCore::Abilities::Segments::UsersByRole.new(role),
              :can, :grid,
              DataCycleCore::Abilities::Segments::SubjectByEnabledFeature.new(:view_mode, DataCycleCore::Feature::ViewMode)
            )
          end
        end
      end
    end
  end
end
