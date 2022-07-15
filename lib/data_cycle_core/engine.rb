# frozen_string_literal: true

# autoload_paths

# rails essentials
require 'rails'
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
require 'active_storage/engine'
require 'action_controller/railtie'
require 'action_mailer/railtie'
require 'action_view/railtie'
require 'action_cable/engine'

# Databases
require 'pg'
require 'activerecord-postgis-adapter'
require 'acts_as_tree'
require 'rgeo'
require 'rgeo-geojson'
require 'rgeo-shapefile'
require 'mongoid'

# event scheduling
require 'ice_cube'
# fix for ice_cube interfering with global i18n hash
require 'ice_cube/railtie'

# authentication
require 'devise'

# authorization
require 'cancancan'

# pagination
require 'kaminari'
# print formatting for e.g. hashes
# require 'awesome_print'
require 'amazing_print'
# validator for json data
require 'json-schema'
# backgound-jobs
require 'delayed_job_active_record'

# REST-client
require 'faraday'
require 'faraday_middleware'

# Breadcrumbs
require 'gretel'

# support for forms
require 'simple_form'

# rendering json responses
require 'jbuilder'

require 'acts_as_paranoid'

require 'transproc/all'
require 'dry-validation'

# carrierwave
require 'carrierwave'
require 'carrierwave_backgrounder'

# redcarpet (for markdown rendering)
require 'redcarpet'

# progress bar
require 'ruby-progressbar'

require 'premailer'

# Image Optimizer
require 'image_optim'
require 'dotenv/load'

# Frontend Asset Loader
require 'vite_rails'

require 'holidays'

module DataCycleCore
  mattr_accessor :breadcrumb_root_name
  self.breadcrumb_root_name = 'Dashboard'

  # :special_data_attributes: @deprecated: remove after APIv2 migrations
  # special data attributes are ignored by the standard json serializes and must be handled by the application itself
  mattr_accessor :special_data_attributes
  self.special_data_attributes = ['id', 'validity_period']

  mattr_accessor :internal_data_attributes
  self.internal_data_attributes = ['date_created', 'date_modified', 'date_deleted', 'is_part_of']

  mattr_accessor :asset_objects
  self.asset_objects = [
    'DataCycleCore::Image',
    'DataCycleCore::Video',
    'DataCycleCore::Audio',
    'DataCycleCore::Pdf',
    'DataCycleCore::DataCycleFile',
    'DataCycleCore::TextFile',
    'DataCycleCore::SrtFile'
  ]

  mattr_accessor :allowed_api_strategies
  self.allowed_api_strategies = [
    'DataCycleCore::Generic::MediaArchive::Webhook',
    'DataCycleCore::Generic::Common::Webhook',
    'DataCycleCore::Generic::FeratelIdentityServer::Webhook',
    'DataCycleCore::Generic::Sulu::Webhook',
    'DataCycleCore::Generic::ExternalLink::Webhook',
    'DataCycleCore::Generic::Amtangee::Webhook'
  ]

  mattr_accessor :excluded_filter_classifications
  self.excluded_filter_classifications = [
    'Angebotszeitraum', 'Antwort', 'Datei', 'Frage', 'Veranstaltungstermin', 'Zeitleiste-Eintrag',
    'Öffnungszeit', 'Öffnungszeit - Zeitspanne', 'Öffnungszeit - Simple', 'Overlay',
    'Publikations-Plan', 'Textblock', 'EventSchedule', 'Skigebiet - Addon', 'Schneehöhe - Messpunkt',
    'Event-Ticket-Angebot', 'Zimmer', 'Zutatengruppe', 'Zutat', 'Rezeptkomponente', 'Angebot', 'Inhaltsblock',
    'Zusatzangebot', 'Wetterprognose', 'Piste', 'Lift'
  ]

  mattr_accessor :ui_locales
  self.ui_locales = [:de, :en]

  mattr_accessor :notification_frequencies
  self.notification_frequencies = ['always', 'named_version', 'day', 'week']

  mattr_accessor :features
  self.features = {}

  mattr_accessor :experimental_features
  self.experimental_features = {}

  mattr_accessor :main_config
  self.main_config = {}

  mattr_accessor :new_dialog
  self.new_dialog = {}

  mattr_accessor :logo
  self.logo = {}

  mattr_accessor :global_configs
  self.global_configs = {}

  mattr_accessor :info_link
  self.info_link = nil
  # inheritable_attributes
  mattr_accessor :inheritable_attributes
  self.inheritable_attributes = ['validity_period']

  # embedded_objects in show
  mattr_accessor :linked_objects_page_size
  self.linked_objects_page_size = 5

  mattr_accessor :max_asynch_classification_items
  self.max_asynch_classification_items = 50

  # webhooks
  mattr_accessor :webhooks
  self.webhooks = Array.wrap(ENV['WEBHOOKS']&.split(',')&.map(&:squish))

  # template directories
  mattr_accessor :template_path
  mattr_accessor :default_template_paths
  self.default_template_paths = []

  # location of import/download configs
  mattr_accessor :external_sources_path

  # location of external_system configs
  mattr_accessor :external_systems_path

  # obsolete: remove after projects initializer update
  mattr_accessor :allowed_content_api_classifications
  self.allowed_content_api_classifications = []

  mattr_accessor :uploader_validations
  self.uploader_validations = {}

  mattr_accessor :default_map_position
  self.default_map_position = {}

  mattr_accessor :content_warnings
  self.content_warnings = {}

  mattr_accessor :classification_visibilities
  self.classification_visibilities = ['show', 'show_more', 'edit', 'api', 'xml', 'filter', 'tile', 'list', 'tree_view']

  mattr_accessor :classification_change_behaviour
  self.classification_change_behaviour = ['trigger_webhooks', 'clear_cache']

  mattr_accessor :cache_invalidation_depth
  self.cache_invalidation_depth = 3

  mattr_accessor :holidays_country_code
  self.holidays_country_code = :at

  mattr_accessor :partial_update_improved
  self.partial_update_improved = false

  mattr_accessor :transitive_classification_paths
  self.transitive_classification_paths = false

  mattr_accessor :persistent_activities
  self.persistent_activities = ['downloads']

  def self.setup
    yield self
  end

  def self.default_classification_visibilities
    classification_visibilities.except(['show_more', 'tree_view'])
  end

  def self.load_configurations(path, include_environments = true)
    path_regex = if include_environments
                   %r{/configurations(?:/(?:#{ActiveRecord::Base.configurations.to_h.keys.without('default').join('|')}))?/(.*)}
                 else
                   %r{/configurations(?!/(?:#{ActiveRecord::Base.configurations.to_h.keys.without('default').join('|')}))/(.*)}
                 end

    Dir[path.to_s].index_with { |f|
      f.delete_suffix('.yml').match(path_regex)&.captures&.first&.split('/')
    }.compact.sort_by { |_k, v| -v.size }.each do |file_name, file_path|
      config_name = file_path.shift

      next unless respond_to?(config_name)

      new_value = YAML.safe_load(ERB.new(File.read(file_name)).result, [Symbol])
      value = try(config_name)

      next unless new_value.present? || new_value.is_a?(FalseClass)

      if value.is_a?(::Hash) && new_value.is_a?(::Hash)
        new_value = file_path.reverse.inject(new_value) { |assigned_value, key| { key => assigned_value } }
        new_value = value.deep_merge(new_value) { |_k, v1, _v2| v1 }.with_indifferent_access
      end

      send("#{config_name}=", new_value).freeze
    end
  end

  class Engine < ::Rails::Engine
    isolate_namespace DataCycleCore

    # config.assets.enabled = false

    # config.generators do |g|
    #   g.assets false
    # end

    # config.assets.version = '1.0'
    # config.assets.precompile += [
    #   'data_cycle_core/*',
    #   'eml-datacycle-border.png',
    #   'eml-datacycle.png',
    #   'location_after.svg',
    #   'location_before.svg',
    #   'location.svg',
    #   'dc-logo_inverted.svg',
    #   'dc-logo.svg',
    #   'dc-logo.png'
    # ]
    config.action_dispatch.cookies_serializer = :json
    # TODO: check: raise_on_unfiltered_parameters never worked in main application
    # config.action_controller.raise_on_unfiltered_parameters = true
    config.action_controller.per_form_csrf_tokens = true
    config.action_controller.forgery_protection_origin_check = true
    # Configure SSL options to enable HSTS with subdomains. Previous versions had false.
    config.ssl_options = { hsts: { subdomains: true } }
    # Make Ruby 2.4 preserve the timezone of the receiver when calling `to_time`.
    # Previous versions had false.
    ActiveSupport.to_time_preserves_timezone = true
    # Enable parameter wrapping for JSON. You can disable this by setting :format to an empty array.
    ActiveSupport.on_load(:action_controller) do
      wrap_parameters format: [:json]
    end

    # use active_record as orm (!not mongoid)
    config.app_generators.orm = :active_record
    config.active_record.schema_format = :sql
    config.active_record.dump_schemas = :all
    config.active_record.default_timezone = :utc # Or :local

    # backend for active_job is delayed_job
    config.active_job.queue_adapter = :delayed_job

    # set default language and no errors for non standard languages
    config.i18n.enforce_available_locales = false
    config.i18n.default_locale = :de
    # fallbacks for i18n and Globalize (buggy with json db-fields)
    # ! when set to true regression with translated jsonb fields occurs
    # !!!!!!!!!!!!!!!! do not switch on !!!!!!!!!!!!!!!!
    config.i18n.fallbacks = false
    config.action_view.form_with_generates_remote_forms = true

    # disable Query logger in development environment
    config.active_record.logger = nil if Rails.env.development? && ENV['RAILS_LOG_TO_STDOUT'].blank?

    # prevent span tags inside HTML-Attributes for missing translations
    config.action_view.debug_missing_translation = false

    # active storage default options
    config.active_storage.resolve_model_to_route = :rails_storage_proxy

    # append engine migration path -> no installation of migrations required
    initializer :append_migrations do |app|
      unless app.root.to_s.match? root.to_s
        config.paths['db/migrate'].expanded.each do |expanded_path|
          app.config.paths['db/migrate'] << expanded_path
        end
      end
    end

    # include rake_tasks
    rake_tasks do
      Dir[File.join(File.dirname(__FILE__), 'tasks/*.rake')].each { |f| load f }
    end

    config.autoload_once_paths << "#{root}/app/middlewares"

    config.before_initialize do |app|
      ### used for backward compatibility (Rails < 5.0)
      app.config.load_defaults 6.1
      app.config.autoloader = :zeitwerk
      app.config.active_record.belongs_to_required_by_default = false
      ###
      app.config.time_zone = 'Europe/Vienna'
      app.config.exceptions_app = routes
      app.middleware.insert_before Rack::Runtime, DataCycleCore::FixParamEncodingMiddleware
    end

    # config.autoload_paths << "/app/vendor/gems/datacycle-connector-legacy/lib"
    # config.autoload_paths << File.expand_path('app/models', __dir__)
    config.to_prepare do
      # binding.pry
      Rails.autoloaders.main.ignore(
        [
          Rails.root.join('app', 'extensions'),
          Rails.root.join('app', 'decorators')
        ]
      )
      Dir.glob(
        [
          Rails.root + 'app/decorators/**/*_decorator*.rb',
          Rails.root + 'app/extensions/**/*.rb'
        ]
      ).each do |c|
        load c
      end

      Devise::Mailer.layout 'data_cycle_core/email' # email.haml or email.erb
      Devise::SessionsController.layout 'data_cycle_core/devise'
      Devise::RegistrationsController.layout 'data_cycle_core/devise'
      Devise::ConfirmationsController.layout 'data_cycle_core/devise'
      Devise::UnlocksController.layout 'data_cycle_core/devise'
      Devise::PasswordsController.layout 'data_cycle_core/devise'
      ActiveStorage::Blob
    end
  end
end
