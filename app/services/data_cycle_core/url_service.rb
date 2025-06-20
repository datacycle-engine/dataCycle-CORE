# frozen_string_literal: true

module DataCycleCore
  class UrlService
    include Singleton
    include DataCycleCore::Engine.routes.url_helpers

    def url_options
      Rails.application.config.action_mailer.default_url_options
    end
  end
end
