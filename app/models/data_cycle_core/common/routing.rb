# frozen_string_literal: true

module DataCycleCore
  module Common
    module Routing
      extend ActiveSupport::Concern

      included do
        include DataCycleCore::Engine.routes.url_helpers
      end

      def default_url_options
        Rails.application.config.action_mailer.default_url_options
      end
    end
  end
end
