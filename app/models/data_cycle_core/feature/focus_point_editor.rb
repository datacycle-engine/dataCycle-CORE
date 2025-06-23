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

        def allowed?(content, user)
          enabled? &&
            attribute_keys.all? { |key| content.respond_to?(key) && user.can?(:update, DataCycleCore::DataAttribute.new(key, content.properties_for(key), {}, content, :update)) } &&
            user.can?(:edit, content)
        end
      end
    end
  end
end
