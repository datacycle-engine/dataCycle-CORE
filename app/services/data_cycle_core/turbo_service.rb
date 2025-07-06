# frozen_string_literal: true

module DataCycleCore
  class TurboService
    class << self
      BROADCAST_ACTIONS = [:update, :append, :prepend, :remove, :replace].freeze

      BROADCAST_ACTIONS.each do |action|
        define_method("broadcast_#{action}_to") do |channel, target: nil, partial: nil, locals: {}, assigns: {}|
          broadcast_action_to(channel, action, target:, partial:, locals:, assigns:)
        end

        define_method("broadcast_localized_#{action}_to") do |channel, target: nil, partial: nil, locals: {}|
          broadcast_localized_action_to(channel, action, target:, partial:, locals:)
        end
      end

      def render(partial:, **kwargs)
        ApplicationController.render(partial: partial, layout: false, **kwargs)
      end

      private

      def broadcast_action_to(channel, action, target: nil, partial: nil, locals: {}, assigns: {})
        Turbo::StreamsChannel.broadcast_action_to(
          channel,
          action:,
          target: target.presence || channel,
          html: render(partial:, locals:, assigns:)
        )
      end

      def broadcast_localized_action_to(channel, action, target: nil, partial: nil, locals: {})
        DataCycleCore.ui_locales.each do |locale|
          broadcast_action_to(
            "#{channel}_#{locale}",
            action,
            target: target.presence || channel,
            partial:,
            locals:,
            assigns: { active_ui_locale: locale }
          )
        end
      end
    end
  end
end
