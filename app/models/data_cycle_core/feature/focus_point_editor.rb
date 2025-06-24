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
