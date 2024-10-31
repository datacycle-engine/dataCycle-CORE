# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module Container
        def self.extend(router)
          router.instance_exec do
            post '/things/:id/set_parent', action: :set_parent, controller: 'things', as: 'set_parent_thing'
          end
        end
      end
    end
  end
end
