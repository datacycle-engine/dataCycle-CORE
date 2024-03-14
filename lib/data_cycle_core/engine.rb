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

require 'dry-transformer'
require 'dry-validation'

# redcarpet (for markdown rendering)
require 'redcarpet'

# progress bar
require 'ruby-progressbar'

require 'premailer'

require 'dotenv/load'

# Frontend Asset Loader
require 'vite_rails'

# Translations
require 'mobility'

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
    'DataCycleCore::Generic::Common::LoggingWebhook',
    'DataCycleCore::Generic::FeratelIdentityServer::Webhook',
    'DataCycleCore::Generic::Sulu::Webhook',
    'DataCycleCore::Generic::ExternalLink::Webhook',
    'DataCycleCore::Generic::Amtangee::Webhook',
    'DataCycleCore::Generic::ExternalContentForm::Webhook',
    'DataCycleCore::Generic::DataCycleApiV4::Webhook'
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

  mattr_accessor :data_definition_mapping
  self.data_definition_mapping = {}

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

  # number of preloaded embedded_objects and linked in show and edit views
  mattr_accessor :linked_objects_page_size
  self.linked_objects_page_size = 5

  mattr_accessor :max_asynch_classification_items
  self.max_asynch_classification_items = 50

  # webhooks
  mattr_accessor :webhooks
  self.webhooks = Array.wrap(ENV['WEBHOOKS']&.split(',')&.map(&:squish))

  # template directories
  mattr_accessor :template_path
  self.template_path = []
  mattr_accessor :default_template_paths
  self.default_template_paths = []

  # location of import/download configs
  mattr_accessor :external_sources_path
  self.external_sources_path = []

  # location of external_system configs
  mattr_accessor :external_systems_path
  self.external_systems_path = []

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
  self.classification_visibilities = ['show', 'api', 'tile', 'show_more', 'xml', 'list', 'edit', 'filter', 'tree_view', 'classification_overview', 'classification_administration']

  mattr_accessor :classification_change_behaviour
  self.classification_change_behaviour = ['trigger_webhooks']

  mattr_accessor :cache_invalidation_depth
  self.cache_invalidation_depth = 3

  mattr_accessor :holidays_country_code
  self.holidays_country_code = :at

  mattr_accessor :partial_update_improved
  self.partial_update_improved = false

  mattr_accessor :persistent_activities
  self.persistent_activities = ['downloads']

  mattr_accessor :user_filters
  self.user_filters = []

  mattr_accessor :header_title
  self.header_title = nil

  mattr_accessor :data_link_bcc
  self.data_link_bcc = nil

  mattr_accessor :classification_icons
  self.classification_icons = {}

  mattr_accessor :external_system_template_paths
  self.external_system_template_paths = []

  mattr_accessor :permissions
  self.permissions = {}

  mattr_accessor :job_queues
  self.job_queues = {
    default: 1,
    importers: 1,
    cache_invalidation: 2,
    search_update: 3,
    mailers: 1,
    webhooks: 1
  }

  def self.setup
    yield self
  end

  def self.default_classification_visibilities
    classification_visibilities.except(['show_more', 'tree_view', 'classification_overview'])
  end

  def self.configuration_paths
    [
      Rails.root.join('config', 'configurations'),
      *Rails.application.railties
        .filter { |railtie| railtie.is_a?(::Rails::Engine) && railtie.root.to_s.match?(%r{vendor/gems/datacycle-}i) }
        .map { |railtie| railtie.root.join('config', 'configurations') }
        .reverse,
      DataCycleCore::Engine.root.join('config', 'configurations')
    ].uniq
  end

  def self.reset_configurations(file_name = '*')
    Dir.glob(configuration_paths.map { |p| File.join(p, file_name) }).map { |p| File.basename(p, '.*') }.uniq.each do |config_name|
      next unless respond_to?(config_name)

      send("#{config_name}=", {})
    end
  end

  def self.load_configurations_for_file(file_name)
    configuration_paths.each do |file_path|
      load_configurations(File.join(file_path, Rails.env, file_name, '**', '*.yml'))
      load_configurations(File.join(file_path, Rails.env, "#{file_name}.yml"))
      load_configurations(File.join(file_path, file_name, '**', '*.yml'), false)
      load_configurations(File.join(file_path, "#{file_name}.yml"))
    end
  end

  def self.load_configurations(path, include_environments = true)
    available_environments = ActiveRecord::Base.configurations.configurations.to_a.map(&:env_name).without('default').join('|')
    path_regex = include_environments ? %r{/configurations(?:/(?:#{available_environments}))?/(.*)} : %r{/configurations(?!/(?:#{available_environments}))/(.*)}

    Dir[path.to_s].index_with { |f|
      f.delete_suffix('.yml').match(path_regex)&.captures&.first&.split('/')
    }.compact.sort_by { |_k, v| -v.size }.each do |file_name, file_path|
      config_name = file_path.shift

      next unless respond_to?(config_name)

      new_value = YAML.safe_load(ERB.new(File.read(file_name)).result, permitted_classes: [Symbol])
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

    config.action_dispatch.cookies_serializer = :json
    config.action_controller.per_form_csrf_tokens = true
    config.action_controller.forgery_protection_origin_check = true
    # Configure SSL options to enable HSTS with subdomains. Previous versions had false.
    config.ssl_options = { hsts: { subdomains: true } }
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

    initializer :append_cable_configurations do |app|
      app.paths['config/cable'] << root.join('config', 'cable.yml').to_s
      ActiveSupport.on_load(:action_cable) do
        config_path = Pathname.new(app.config.paths['config/cable'].find { |p| Pathname.new(p).exist? })
        self.cable = Rails.application.config_for(config_path).to_h.with_indifferent_access if config_path
      end
    end

    # include rake_tasks
    rake_tasks do
      Dir[File.join(File.dirname(__FILE__), 'tasks/*.rake')].each { |f| load f }
    end

    config.autoload_once_paths << "#{root}/app/middlewares"
    config.autoload_paths += Dir['vendor/gems/datacycle-*/lib']
    config.eager_load_paths += Dir['vendor/gems/datacycle-*/lib']

    if Rails.env.development? # needed for reloading yml configurations in development context
      config.eager_load_paths += Dir['config/configurations/**/*.yml']
      config.eager_load_paths += Dir['vendor/gems/data-cycle-core/config/configurations/**/*.yml']
      config.eager_load_paths += Dir['vendor/gems/datacycle-*/config/configurations/**/*.yml']
    end

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

    config.to_prepare do
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

      ActionMailer::Base.layout -> { @resource.try(:mailer_layout)&.then { |l| l.starts_with?('data_cycle_core/') ? l : "data_cycle_core/#{l}" } || 'data_cycle_core/mailer' }
      ActionMailer::Base.default from: ->(_) { @resource.try(:mailer_from) || Rails.configuration.action_mailer.default_options[:from] }
      ActionMailer::Base.helper 'data_cycle_core/email'
      ActiveSupport.on_load :action_mailer do
        include DataCycleCore::EmailHelper
      end

      Devise::SessionsController.layout 'data_cycle_core/devise'
      Devise::RegistrationsController.layout 'data_cycle_core/devise'
      Devise::ConfirmationsController.layout 'data_cycle_core/devise'
      Devise::UnlocksController.layout 'data_cycle_core/devise'
      Devise::PasswordsController.layout 'data_cycle_core/devise'
      ActiveStorage::Blob
    end
  end
end
