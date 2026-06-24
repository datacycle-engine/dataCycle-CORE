# frozen_string_literal: true

module DataCycleCore
  module Feature
    # Manages view mode preferences and permissions across different contexts.
    #
    # ViewMode controls which display modes (grid, list, map) are available to users
    # based on feature configuration and user abilities. It supports context-specific
    # mode filtering (e.g., 'users' context only allows 'grid' and 'list' modes).
    #
    # @example Get allowed modes for a user
    #   DataCycleCore::Feature::ViewMode.allowed_modes(user, 'users') #=> ['grid', 'list']
    #
    # @example Check if map mode is enabled
    #   DataCycleCore::Feature::ViewMode.map_enabled? #=> true
    class ViewMode < Base
      class << self
        VIEW_MODES_BY_CONTEXT = {
          'users' => ['grid', 'list']
        }.freeze

        def ability_class
          DataCycleCore::Feature::Abilities::ViewMode
        end

        def allowed_modes(user = nil, context = nil)
          modes = ['grid']
          return modes unless enabled? && !user.nil?

          config_modes = enabled_modes
          config_modes = config_modes.intersection(VIEW_MODES_BY_CONTEXT[context]) if VIEW_MODES_BY_CONTEXT.key?(context)
          config_modes.select { |mode| user.can?(mode.to_sym, :view_mode) }.presence || modes
        end

        def map_enabled?
          enabled? && enabled_modes.include?('map')
        end

        private

        def enabled_modes
          Array.wrap(configuration['allowed'])
        end
      end
    end
  end
end
