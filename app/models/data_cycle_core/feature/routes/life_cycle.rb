# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module LifeCycle
        def self.extend(router)
          router.instance_exec do
            patch '/things/:id/update_life_cycle', action: :update_life_cycle, controller: 'things', as: 'update_life_cycle_thing'
          end
        end
      end
    end
  end
end
