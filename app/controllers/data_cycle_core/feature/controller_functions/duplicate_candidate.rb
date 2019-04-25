# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module DuplicateCandidate
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.append do
            get '/things/:id/merge_with_duplicate/:duplicate_id', action: :merge_with_duplicate, controller: 'things', as: 'merge_with_duplicate_thing' unless has_named_route?(:merge_with_duplicate_thing)
          end
          Rails.application.reload_routes!
        end

        def merge_with_duplicate
          # binding.pry
        end

        private

        def merge_params
        end
      end
    end
  end
end
