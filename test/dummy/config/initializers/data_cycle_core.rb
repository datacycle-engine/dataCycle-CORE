# frozen_string_literal: true

DataCycleCore.setup do |_config|
  I18n.available_locales = [:de, :en].freeze

  Rails.application.config.filter_parameters += [:password]

  Rails.application.config.session_store :cookie_store, key: '_dummy_session', same_site: :lax
end
