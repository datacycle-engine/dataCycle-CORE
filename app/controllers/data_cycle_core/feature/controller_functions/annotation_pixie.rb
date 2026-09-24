# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      # Focus point suggestion for the annotationPixie (DataCycleCore::Feature::AnnotationPixie),
      # mixed into the contents controller while that feature is enabled.
      module AnnotationPixie
        extend ActiveSupport::Concern
        include DataCycleCore::ImageAnnotationConcern

        # POST a focus point suggestion for an image. Answers +{ focus_point: { x:, y: } }+; a
        # service that returns no focus point is a valid result and answers +{ focus_point: nil }+.
        # A focus point is language independent, so a stored annotation that has one answers this
        # endpoint whatever it was generated for -- which is what ImageAnnotationConcern reads out
        # of a payload carrying a value.
        def focus_point_suggestion
          feature = DataCycleCore::Feature::AnnotationPixie

          with_image_annotation(feature) do |data, _content|
            { focus_point: feature.focus_point_from(data) }
          end
        end
      end
    end
  end
end
