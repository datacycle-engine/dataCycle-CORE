# frozen_string_literal: true

DataCycleCore.setup do |config|
  # general settings
  I18n.available_locales = [:de, :en].freeze

  # Configure sensitive parameters which will be filtered from the log file.
  Rails.application.config.filter_parameters += [:password]

  Rails.application.config.session_store :cookie_store, key: '_dummy_session', same_site: :lax

  config.external_sources_path = Rails.root.join('..', 'dummy', 'config', 'external_sources').freeze
  config.external_systems_path = Rails.root.join('..', 'dummy', 'config', 'external_systems').freeze
  config.partial_update_improved = true

  if Rails.env.test?
    config.default_template_paths = [
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_basic'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_creative_content'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_media'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'feature_container'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'feature_life_cycle'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'feature_releasable')
    ].freeze
  else
    config.default_template_paths = [
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_basic'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_creative_content'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_media')
    ].freeze
  end
end
