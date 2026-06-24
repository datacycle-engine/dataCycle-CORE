# frozen_string_literal: true

module DataCycleCore
  class TurboService
    class << self
      BROADCAST_ACTIONS = [:update, :append, :prepend, :remove, :replace].freeze

      BROADCAST_ACTIONS.each do |action|
        define_method("broadcast_#{action}_to") do |channel, target: nil, partial: nil, locals: {}, assigns: {}, attributes: {}, html: nil|
          broadcast_action_to(channel, action, target:, partial:, locals:, assigns:, attributes:, html:)
        end

        define_method("broadcast_localized_#{action}_to") do |channel, target: nil, partial: nil, locals: {}, attributes: {}|
          broadcast_localized_action_to(channel, action, target:, partial:, locals:, attributes:)
        end
      end

      def render(partial:, **)
        ApplicationController.render(partial: partial, layout: false, **)
      end

      private

      def broadcast_action_to(channel, action, target: nil, partial: nil, locals: {}, assigns: {}, attributes: {}, html: nil)
        ::Turbo::StreamsChannel.broadcast_action_to(
          channel,
          action:,
          attributes:,
          target: target.presence || channel,
          html: html.presence || render(partial:, locals:, assigns:)
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
