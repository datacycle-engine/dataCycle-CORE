# frozen_string_literal: true

module DataCycleCore
  module Feature
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

          config_modes = Array.wrap(configuration['allowed'])
          config_modes = config_modes.intersection(VIEW_MODES_BY_CONTEXT[context]) if VIEW_MODES_BY_CONTEXT.key?(context)
          config_modes.select { |mode| user.can?(mode.to_sym, :view_mode) }.presence || modes
        end
      end
    end
  end
end
