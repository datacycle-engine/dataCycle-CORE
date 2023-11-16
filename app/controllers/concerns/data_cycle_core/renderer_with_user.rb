# frozen_string_literal: true

module DataCycleCore
  module RendererWithUser
    extend ActiveSupport::Concern

    class_methods do
      def renderer_with_user(user, **)
        ActionController::Renderer::RACK_KEY_TRANSLATION['warden'] ||= 'warden'
        proxy = Warden::Proxy.new(Devise.warden_config, Warden::Manager.new(Devise.warden_config)).tap do |i|
          i.set_user(user, scope: :user, store: false, run_callbacks: false)
        end

        renderer.new(warden: proxy, **)
      end
    end
  end
end
