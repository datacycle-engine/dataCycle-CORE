# frozen_string_literal: true

module DataCycleCore
  module Feature
    class GravityEditor < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::GravityEditor
        end

        def routes_module
          DataCycleCore::Feature::Routes::GravityEditor
        end

        def allowed?(content)
          super && content.respond_to?(primary_attribute_key)
        end

        # The bare per-attribute right, not Base#attribute_editable?: this feature writes an
        # `:visible: api` attribute through its own endpoint, so it has no editor for
        # #can_attribute? to allow -- see test/models/feature/attribute_editable_test.rb.
        def user_can_edit?(content, user)
          allowed?(content) &&
            user.can?(:update, content) &&
            user.can?(:update,
                      DataCycleCore::DataAttribute.new(
                        primary_attribute_key,
                        content.properties_for(primary_attribute_key),
                        {},
                        content,
                        :update
                      ))
        end

        def transform_gravity!(options, params)
          gravity = params&.dig(primary_attribute_key)
          return if gravity.blank?

          value = DataCycleCore::Concept.find_by(id: gravity)&.uri&.split('#')&.last
          return if value.blank?

          options['gravity'] = value
        end
      end
    end
  end
end
