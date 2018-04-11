DataCycleCore.setup do |config|

  # gem initializers
  I18n.available_locales = [:de]

# Version of your assets, change this if you want to expire all your assets.
  Rails.application.config.assets.version = '1.0'
  Rails.application.config.assets.precompile += ['logo.svg', 'logo.png']

  Rails.application.config.action_dispatch.cookies_serializer = :json

  Rails.application.config.filter_parameters += [:password]

  Rails.application.config.action_controller.raise_on_unfiltered_parameters = true

# Enable per-form CSRF tokens. Previous versions had false.
  Rails.application.config.action_controller.per_form_csrf_tokens = true

# Enable origin-checking CSRF mitigation. Previous versions had false.
  Rails.application.config.action_controller.forgery_protection_origin_check = true

# Make Ruby 2.4 preserve the timezone of the receiver when calling `to_time`.
# Previous versions had false.
  ActiveSupport.to_time_preserves_timezone = true

# Require `belongs_to` associations by default. Previous versions had false.
  Rails.application.config.active_record.belongs_to_required_by_default = true

# Do not halt callback chains when a callback returns false. Previous versions had true.
  ActiveSupport.halt_callback_chains_on_return_false = false

# Configure SSL options to enable HSTS with subdomains. Previous versions had false.
  Rails.application.config.ssl_options = { hsts: { subdomains: true } }
  Rails.application.config.session_store :cookie_store, key: '_dummy_session'

# Enable parameter wrapping for JSON. You can disable this by setting :format to an empty array.
  ActiveSupport.on_load(:action_controller) do
    wrap_parameters format: [:json]
  end


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
