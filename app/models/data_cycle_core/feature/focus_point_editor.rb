# frozen_string_literal: true

module DataCycleCore
  module Feature
    class FocusPointEditor < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::FocusPointEditor
        end

        def routes_module
          DataCycleCore::Feature::Routes::FocusPointEditor
        end

        # The bare per-attribute right, not Base#attribute_editable?: this feature writes an
        # `:visible: api` attribute through its own endpoint, so it has no editor for
        # #can_attribute? to allow -- see test/models/feature/attribute_editable_test.rb.
        def user_can_edit?(content, user)
          allowed?(content) && attribute_keys.all? { |key| user.can?(:update, DataCycleCore::DataAttribute.new(key, content.properties_for(key), {}, content, :update)) } &&
            user.can?(:edit, content)
        end

        def apply_focus_point!(options, params)
          x, y = params&.values_at(*attribute_keys)
          return if x.nil? || y.nil?

          options['gravity'] = "fp:#{x}:#{y}"
        end
      end
    end
  end
end
