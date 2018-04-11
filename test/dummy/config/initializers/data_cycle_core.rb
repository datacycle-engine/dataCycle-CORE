DataCycleCore.setup do |config|
  # general settings
  I18n.available_locales = [:de]
  # Precompile additional assets.
  # application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
  # Rails.application.config.assets.precompile += %w( search.js )
  Rails.application.config.assets.precompile += ['logo.svg', 'logo.png']
  # Configure sensitive parameters which will be filtered from the log file.
  Rails.application.config.filter_parameters += [:password]

  # Make Ruby 2.4 preserve the timezone of the receiver when calling `to_time`.
  # Previous versions had false.
  ActiveSupport.to_time_preserves_timezone = true

  # Do not halt callback chains when a callback returns false. Previous versions had true.
  ActiveSupport.halt_callback_chains_on_return_false = false

  # Enable parameter wrapping for JSON. You can disable this by setting :format to an empty array.
  ActiveSupport.on_load(:action_controller) do
    wrap_parameters format: [:json]
  end

  # Configure SSL options to enable HSTS with subdomains. Previous versions had false.
  Rails.application.config.ssl_options = { hsts: { subdomains: true } }
  Rails.application.config.session_store :cookie_store, key: '_dummy_session'

  # DataCycleCore settings
  config.access_tokens = [
    'd48a84faseei512hjkl159ggg9a72adf'
  ]

  config.template_path = Rails.root.join('config', 'data_definitions').freeze
  config.default_template_paths = [
    Rails.root.join('..', '..', 'config', 'data_definitions', 'basic'),
    Rails.root.join('..', '..', 'config', 'data_definitions', 'enhanced'),
    Rails.root.join('..', '..', 'config', 'data_definitions', 'media_archive')
    # Rails.root.join('..', '..', 'config', 'data_definitions', 'container')
    # Rails.root.join('..', '..', 'config', 'data_definitions', 'test')
  ].freeze

  config.external_sources_path = Rails.root.join('config', 'external_sources').freeze

  # config.excluded_new_item_objects = ['Event', 'Person', 'Örtlichkeit', 'Bild', 'Organization', 'Zeitleiste', 'Linktipps', 'Datei']

  config.features = config.features.merge(
    {
      overlay: {
        enabled: true
      }
    }
  ).freeze
end
