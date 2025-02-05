# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module Normalize
        def self.extend(router)
          router.instance_exec do
            post '/things/:id/normalize', action: :normalize, controller: 'things', as: 'normalize_thing'
          end
        end
      end
    end
  end
end
