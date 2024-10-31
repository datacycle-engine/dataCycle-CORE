# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module DuplicateCandidate
        def self.extend(router)
          router.instance_exec do
            scope '(/watch_lists/:watch_list_id)', defaults: { watch_list_id: nil } do
              get '/things/:id/merge_with_duplicate(/:source_id)', action: :merge_with_duplicate, controller: 'things', as: 'merge_with_duplicate_thing'
              post '/things/:id/false_positive_duplicate/:source_id', action: :false_positive_duplicate, controller: 'things', as: 'false_positive_duplicate_thing'
              get '/things/:id/validate_duplicate/:source_id', action: :validate_duplicate, controller: 'things', as: 'validate_duplicate_thing'
            end
          end
        end
      end
    end
  end
end
