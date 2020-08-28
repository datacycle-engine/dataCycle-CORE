# frozen_string_literal: true

module DataCycleCore
  module Feature
    class ViewMode < Base
      class << self
        def ability_class
          DataCycleCore::Feature::Abilities::ViewMode
        end

        def allowed_modes(user = nil)
          return [] unless enabled? && !user.nil?

          Array(configuration.dig('allowed')&.select { |mode| user.can?(mode.to_sym, :view_mode) })
        end
      end
    end
  end
end
