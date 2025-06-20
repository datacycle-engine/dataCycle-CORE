# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module FocusPointEditor
        def self.extend(router)
          router.instance_exec do
            authenticate do
              patch '/things/:id/update_focus_point', action: :update_focus_point, controller: 'things', as: 'update_focus_point'
            end
          end
        end
      end
    end
  end
end
