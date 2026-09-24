# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      # Route of the annotationPixie's focus point suggestion (DataCycleCore::Feature::AnnotationPixie).
      module AnnotationPixie
        # @param router [ActionDispatch::Routing::Mapper] router the route is drawn on
        def self.extend(router)
          router.instance_exec do
            authenticate do
              # collection route: the focus point is also suggested for an image that has been
              # uploaded but has no content yet, so there is no thing id to nest it under.
              post '/things/focus_point_suggestion', action: :focus_point_suggestion, controller: 'things', as: 'focus_point_suggestion_things'
            end
          end
        end
      end
    end
  end
end
