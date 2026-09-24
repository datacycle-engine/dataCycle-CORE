# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Frontend feature that annotates images while they are being edited: classification suggestions
    # per eligible concept scheme (vision, via the content_classifier backend feature) and a focus
    # point (via the embedding backend feature / PixieLens). Both backends live in plugin gems and
    # are declared as :dependencies:, so the pixie is only available where they are -- see
    # ClassificationPixie for the same composition.
    #
    # The feature deliberately holds no write path of its own. Its classification suggestions are
    # rendered into the regular edit form (detail edit) or the upload mask and persisted by the
    # ordinary save (PATCH /things/:id, POST /things/bulk_create); its focus point is offered on the
    # detail page, beside the focus point editor and through that editor's own
    # PATCH /things/:id/update_focus_point.
    class AnnotationPixie < Base
      class << self
        include DataCycleCore::Feature::Concerns::ImageContent

        # @return [Module] focus point suggestion action, mixed into the contents controller
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::AnnotationPixie
        end

        # @return [Module] route for that action
        def routes_module
          DataCycleCore::Feature::Routes::AnnotationPixie
        end

        # The focus point of an annotation, as focus_point_x/focus_point_y take it. A missing or
        # incomplete one is a valid answer, not an error.
        #
        # Both coordinates are fractions of the image's width and height, which is what the editor
        # multiplies its crosshair position by and what PATCH /things/:id/update_focus_point stores.
        # A value outside 0..1 is clamped rather than passed on: the editor's own
        # #calculateCrossHairPosition keeps the crosshair inside the image, so a service answering
        # x = 1.4 would show a point on the right edge and persist one 40% past it.
        #
        # @param data [Hash] the annotations of the image
        # @return [Hash, nil] +{ 'x' =>, 'y' => }+
        def focus_point_from(data)
          focus_point = data.to_h['focus_point']
          return unless focus_point.is_a?(::Hash)

          x = Float(focus_point['x'], exception: false)
          y = Float(focus_point['y'], exception: false)
          return if x.nil? || y.nil?

          { 'x' => x.clamp(0.0, 1.0), 'y' => y.clamp(0.0, 1.0) }
        end

        # Concept schemes the user may classify this content on, as
        # [{ 'concept_scheme_name', 'property_key', 'concept_scheme_id' }, ...].
        #
        # Resolved by Content::Extensions::ClassifiableSchemes, so eligibility -- concept scheme
        # visibility, per-attribute edit rights, overlay attributes and the
        # universal_classifications fallback -- has exactly one implementation, shared with the
        # content_classifier gem's own endpoints.
        def eligible_properties(content, user)
          return [] if content.blank? || user.blank?

          Array.wrap(content.allowed_properties_for_user(user))
        end

        # True when the scheme has an attribute of its own on this template, i.e. the regular
        # classification editor already renders it and the pixie only has to add its button.
        def dedicated_property?(content, property)
          content.properties_for(property['property_key'])&.dig('tree_label').to_s == property['concept_scheme_name'].to_s
        end

        # The eligible scheme this classification attribute is the dedicated editor of, if any --
        # those editors already exist in the form and only need the pixie's generate button, while
        # the schemes without one are rendered by the pixie itself (see #undedicated_properties).
        def dedicated_property_for(content, key, user)
          attribute_name = key.to_s.attribute_name_from_key

          eligible_properties(content, user).find do |property|
            property['property_key'] == attribute_name && dedicated_property?(content, property)
          end
        end

        # The eligible schemes that resolved to a shared property (universal_classifications) and
        # therefore have no editor of their own -- the pixie renders one per scheme.
        def undedicated_properties(content, user)
          eligible_properties(content, user).reject { |property| dedicated_property?(content, property) }
        end

        # Everything the pixie's editor block needs, resolved in one place so its two halves cannot
        # drift apart:
        #
        #   :editors  one entry per scheme the pixie renders an editor for, the eligible property
        #             plus the classifications the content already carries from that scheme
        #   :retained property key => classification ids the pixie renders no editor for
        #
        # +:retained+ exists because several schemes share one property here: saving replaces the
        # whole relation (Content::DataHash#set_classification_relation_ids), so ids belonging to
        # schemes without an editor have to be submitted again or they are deleted.
        #
        # @param content [DataCycleCore::Thing] content or template thing being edited
        # @param user [DataCycleCore::User]
        # @param property_key [String, nil] limit to the schemes that resolved to this attribute --
        #   the detail edit form renders the block once per shared attribute, in its position
        # @return [Hash{Symbol => Array, Hash}]
        def editor_configuration(content, user, property_key: nil)
          properties = renderable_properties(undedicated_properties(content, user))
          properties = properties.select { |property| property['property_key'] == property_key } if property_key.present?
          return { editors: [], retained: {} } if properties.blank?

          editors = []
          retained = {}

          properties.group_by { |property| property['property_key'] }.each do |grouped_key, scheme_properties|
            current = Array(content.try(grouped_key))
            schemes = DataCycleCore::Concept.concept_scheme_ids_by_concept(current.map { |concept| concept.id.to_s })
            rendered_scheme_ids = scheme_properties.pluck('concept_scheme_id').map(&:to_s)

            scheme_properties.each do |property|
              editors << property.merge(
                'classifications' => current.select { |classification| schemes[classification.id.to_s]&.include?(property['concept_scheme_id'].to_s) },
                'definition' => editor_definition(content, property)
              )
            end

            retained[grouped_key] = current
              .reject { |classification| schemes[classification.id.to_s]&.intersect?(rendered_scheme_ids) }
              .map { |classification| classification.id.to_s }
          end

          { editors:, retained: }
        end

        # The attribute definition one of those editors renders from. The shared property carries no
        # tree_label of its own, and it is the tree_label that scopes the select's options and names
        # the editor -- Content::Extensions::Translation#human_property_name already prefers it over
        # the attribute label for universal_classifications, so the editor is titled with the
        # concept scheme.
        #
        # @return [Hash]
        def editor_definition(content, property)
          content.properties_for(property['property_key']).deep_merge(
            'tree_label' => property['concept_scheme_name'],
            'ui' => { 'edit' => { 'data_attributes' => { 'concept_scheme_id' => property['concept_scheme_id'], 'property_key' => property['property_key'], 'no_copy_to_all' => true } } }
          )
        end

        # Drops schemes without concepts: there is nothing to suggest or select from, and the
        # classification editor renders nothing for an empty tree either. ConceptScheme.with_concepts
        # carries why it is an EXISTS -- it matters here because the upload mask renders this once
        # per uploaded file.
        #
        # @param properties [Array<Hash>]
        # @return [Array<Hash>]
        def renderable_properties(properties)
          return properties if properties.blank?

          filled = DataCycleCore::ConceptScheme
            .where(id: properties.pluck('concept_scheme_id'))
            .with_concepts
            .reorder(nil)
            .pluck(:id)
            .map(&:to_s)

          properties.select { |property| filled.include?(property['concept_scheme_id'].to_s) }
        end
      end
    end
  end
end
