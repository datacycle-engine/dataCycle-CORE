# frozen_string_literal: true

module DataCycleCore
  module Content
    module Extensions
      # Which concept schemes a user may classify this content on, and through which attribute.
      #
      # In core rather than in the content_classifier gem that first needed it, because nothing in
      # the resolution is gem specific: ConceptScheme.visible, #classification_properties,
      # #overlay_property_names_for and the universal_classifications convention are all core's, and
      # the only tie to the gem is the visibility context a project marks its schemes with -- data,
      # like the 'api' and 'tree_view' contexts core already reads. Feature::AnnotationPixie and the
      # gem's endpoints answer from this one implementation, so core's test suite pins the behaviour
      # the gem ships rather than a stand-in's approximation of it.
      module ClassifiableSchemes
        extend ActiveSupport::Concern

        # visibility context a project marks a concept scheme with to offer it for classification.
        # ConceptScheme owns the vocabulary: this is its :content_tools group, whose sole member the
        # context is.
        CLASSIFIABLE_VISIBILITY = DataCycleCore::ConceptScheme::VISIBILITY_GROUPS[:content_tools].first
        # the shared attribute a scheme without a dedicated one is classified through
        UNIVERSAL_PROPERTY_NAME = 'universal_classifications'

        # Memoized per user for the life of this instance: one request asks it once per pixie button
        # and once more for the block that renders them, and the answer depends on nothing else.
        #
        # @param user [DataCycleCore::User, nil]
        # @return [Array<Hash>] { 'concept_scheme_name', 'property_key', 'concept_scheme_id' } for
        #   each scheme the user may classify this content on, in scheme name order
        def allowed_properties_for_user(user)
          return [] if user.blank?

          @allowed_properties_for_user ||= {}
          @allowed_properties_for_user[user.id] ||= resolve_allowed_properties_for_user(user)
        end

        # The attribute one scheme is classified through: the scheme's own, an overlay of it the user
        # may write where the original is read only, or the shared universal_classifications.
        #
        # Public because it is also the write path's re-verification: an apply request names the
        # property key the form was rendered with, and the content_classifier gem's
        # Base#resolve_property_name_for_apply resolves it again through here so a tampered request
        # cannot write an attribute the user may not edit.
        #
        # @param scheme_properties [Hash] the classification properties that name one scheme
        # @param user [DataCycleCore::User, nil]
        # @return [String, nil] nil when the user may write none of the three
        def classifiable_property_name(scheme_properties, user)
          return if user.blank?

          property_name = scheme_properties.keys.first

          if property_name.present?
            return property_name if classifiable_attribute?(property_name, user)

            overlay_name = overlay_property_names_for(property_name, exclude_types: 'overlay')
              .find { |name| classifiable_attribute?(name, user) }
            return overlay_name if overlay_name.present?
          end

          UNIVERSAL_PROPERTY_NAME if classifiable_attribute?(UNIVERSAL_PROPERTY_NAME, user)
        end

        # @return [Boolean] whether this attribute has an editor the user may write, which is what
        #   makes it usable for classifying -- both the pixie's suggestions and the classifier's
        #   apply go through the ordinary form
        def classifiable_attribute?(property_name, user)
          DataCycleCore::Feature::Base.attribute_editable?(self, property_name, user)
        end

        private

        def resolve_allowed_properties_for_user(user)
          # hoisted: #classification_properties is #property_selector, which rebuilds a filtered copy
          # of every property definition on each call and does not depend on the scheme
          properties = classification_properties

          DataCycleCore::ConceptScheme.visible(CLASSIFIABLE_VISIBILITY).order(:name).filter_map do |scheme|
            scheme_properties = properties.select do |_key, definition|
              definition.is_a?(::Hash) && (definition['tree_label'].to_s == scheme.name || definition['universal'])
            end

            property_key = classifiable_property_name(scheme_properties, user)
            next if property_key.blank?

            { 'concept_scheme_name' => scheme.name, 'property_key' => property_key, 'concept_scheme_id' => scheme.id }
          end
        end
      end
    end
  end
end
