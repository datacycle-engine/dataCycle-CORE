# frozen_string_literal: true

DataCycleCore.setup do |config|
  # general settings
  I18n.available_locales = [:de, :en].freeze

  # only required for DataCycleCore dummy app
  Rails.application.config.assets.precompile += ['logo.svg', 'logo.png', 'location.svg']
  # Configure sensitive parameters which will be filtered from the log file.
  Rails.application.config.filter_parameters += [:password]
  # Require `belongs_to` associations by default. Previous versions had false.
  Rails.application.config.active_record.belongs_to_required_by_default = true
  Rails.application.config.session_store :cookie_store, key: '_dummy_session'

  # config.template_path = Rails.root.join('config', 'data_definitions').freeze

  config.external_sources_path = Rails.root.join('..', '..', 'config', 'external_sources').freeze
  config.external_systems_path = Rails.root.join('..', '..', 'config', 'external_systems').freeze

  if Rails.env.test?
    config.default_template_paths = [
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_basic'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_creative_content'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_media'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'feature_life_cycle'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'feature_idea_collection'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'external_source_bergfex')
    ].freeze
  else
    config.default_template_paths = [
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_basic'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_creative_content'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'data_cycle_media'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'external_source_bergfex')
      # Rails.root.join('..', '..', 'config', 'data_definitions', 'feature_releasable'),
      # Rails.root.join('..', '..', 'config', 'data_definitions', 'feature_life_cycle'),
      # Rails.root.join('..', '..', 'config', 'data_definitions', 'feature_idea_collection')
    ].freeze
  end

  config.max_asynch_classification_items = 5

  config.webhooks = ['Local-Text-File']

  config.webhooks = ['Local-Text-File'] if Rails.env.test?
end
