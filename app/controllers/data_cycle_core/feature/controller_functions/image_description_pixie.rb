# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      # Text suggestions for the imageDescriptionPixie
      # (DataCycleCore::Feature::ImageDescriptionPixie), mixed into the contents controller while
      # that feature is enabled.
      module ImageDescriptionPixie
        extend ActiveSupport::Concern
        include DataCycleCore::ImageAnnotationConcern

        # POST text suggestions for an image. Answers +{ texts: { <attribute_key> => { <locale> =>
        # "..." } } }+, one entry per opted-in attribute the requester may edit, for the one locale
        # the request named.
        #
        # A stored annotation answers this endpoint only where it carries a text for the locale
        # being edited: one generated in German alone leaves an English editor to the service. That
        # falls out of the empty texts hash ImageAnnotationConcern reads as "not an answer".
        def description_suggestion
          feature = DataCycleCore::Feature::ImageDescriptionPixie

          with_image_annotation(feature) do |data, content|
            { texts: feature.suggestions(data, content, current_user, image_annotation_locale) }
          end
        end
      end
    end
  end
end
