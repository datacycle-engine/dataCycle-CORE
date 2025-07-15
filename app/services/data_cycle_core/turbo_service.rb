# frozen_string_literal: true

module DataCycleCore
  class TurboService
    class << self
      BROADCAST_ACTIONS = [:update, :append, :prepend, :remove, :replace].freeze

      BROADCAST_ACTIONS.each do |action|
        define_method("broadcast_#{action}_to") do |channel, target: nil, partial: nil, locals: {}, assigns: {}, attributes: {}|
          broadcast_action_to(channel, action, target:, partial:, locals:, assigns:, attributes:)
        end

        define_method("broadcast_localized_#{action}_to") do |channel, target: nil, partial: nil, locals: {}, attributes: {}|
          broadcast_localized_action_to(channel, action, target:, partial:, locals:, attributes:)
        end
      end

      def render(partial:, **kwargs)
        ApplicationController.render(partial: partial, layout: false, **kwargs)
      end

      private

      def broadcast_action_to(channel, action, target: nil, partial: nil, locals: {}, assigns: {}, attributes: {})
        ::Turbo::StreamsChannel.broadcast_action_to(
          channel,
          action:,
          attributes:,
          target: target.presence || channel,
          html: render(partial:, locals:, assigns:)
        )
      end

      def broadcast_localized_action_to(channel, action, target: nil, partial: nil, locals: {}, attributes: {})
        DataCycleCore.ui_locales.each do |locale|
          broadcast_action_to(
            "#{channel}_#{locale}",
            action,
            target: target.presence || channel,
            partial:,
            locals:,
            attributes:,
            assigns: { active_ui_locale: locale }
          )
        end
      end
    end
  end
end
