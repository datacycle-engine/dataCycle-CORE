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

        def allowed?(content, user)
          enabled? &&
            content.respond_to?(primary_attribute_key) &&
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
      end
    end
  end
end
