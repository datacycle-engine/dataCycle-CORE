# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      # Route of the imageDescriptionPixie's text suggestion (DataCycleCore::Feature::ImageDescriptionPixie).
      module ImageDescriptionPixie
        # @param router [ActionDispatch::Routing::Mapper] router the route is drawn on
        def self.extend(router)
          router.instance_exec do
            authenticate do
              # collection route: texts are also suggested for an image that has been uploaded but
              # has no content yet, so there is no thing id to nest it under.
              post '/things/description_suggestion', action: :description_suggestion, controller: 'things', as: 'description_suggestion_things'
            end
          end
        end
      end
    end
  end
end
