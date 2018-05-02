DataCycleCore.setup do |config|
  # general settings
  I18n.available_locales = [:de]
  # only required for DataCycleCore dummy app
  Rails.application.config.assets.precompile += ['logo.svg', 'logo.png']
  # Configure sensitive parameters which will be filtered from the log file.
  Rails.application.config.filter_parameters += [:password]
  # Require `belongs_to` associations by default. Previous versions had false.
  Rails.application.config.active_record.belongs_to_required_by_default = true
  Rails.application.config.session_store :cookie_store, key: '_dummy_session'

  # DataCycleCore settings
  config.access_tokens = [
    'd48a84faseei512hjkl159ggg9a72adf'
  ]

  config.template_path = Rails.root.join('config', 'data_definitions').freeze

  if ENV['RAILS_ENV'] == 'test'
    config.default_template_paths = [
      Rails.root.join('..', '..', 'config', 'data_definitions', 'gitlab_ci')
    ].freeze
    config.excluded_new_item_objects = ['Event', 'Person', 'Örtlichkeit', 'Bild', 'Organization', 'Zeitleiste', 'Linktipps', 'Datei', 'Tour', 'Video', 'Unterkunft']
  else
    config.default_template_paths = [
      Rails.root.join('..', '..', 'config', 'data_definitions', 'basic'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'enhanced'),
      Rails.root.join('..', '..', 'config', 'data_definitions', 'media_archive')
      # Rails.root.join('..', '..', 'config', 'data_definitions', 'container')
      # Rails.root.join('..', '..', 'config', 'data_definitions', 'test')
      # Rails.root.join('..', '..', 'config', 'data_definitions', 'gitlab_ci')
    ].freeze
  end

  config.external_sources_path = Rails.root.join('config', 'external_sources').freeze
  # config.excluded_new_item_objects = ['Event', 'Person', 'Örtlichkeit', 'Bild', 'Organization', 'Zeitleiste', 'Linktipps', 'Datei', 'Tour', 'Video', 'Unterkunft']

  config.features = config.features.merge(
    {
      publication_schedule: {
        enabled: true,
        classification_keys: ['output_channel']
      },
      overlay: {
        enabled: true
      },
      releasable: {
        enabled: true
      },
      container: {
        enabled: true,
        excluded: ['Bild', 'Video']
      }
    }
  ).freeze
end
