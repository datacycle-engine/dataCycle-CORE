# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module GravityEditor
        def self.extend(router)
          router.instance_exec do
            authenticate do
              patch '/things/:id/update_gravity', action: :update_gravity, controller: 'things', as: 'update_gravity_thing'
            end
          end
        end
      end
    end
  end
end
