# frozen_string_literal: true

module DataCycleCore
  module Feature
    class ViewMode < Base
      class << self
        def ability_class
          DataCycleCore::Feature::Abilities::ViewMode
        end

        def allowed_modes(user = nil)
          modes = ['grid']
          return modes unless enabled? && !user.nil?

          Array.wrap(configuration.dig('allowed')&.select { |mode| user.can?(mode.to_sym, :view_mode) }).presence || modes
        end
      end
    end
  end
end
