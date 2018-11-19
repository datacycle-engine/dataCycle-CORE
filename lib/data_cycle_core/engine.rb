# frozen_string_literal: true

# rails essentials
require 'rails'

# Databases
require 'pg'
require 'activerecord-postgis-adapter'
require 'acts_as_tree'
require 'rgeo'
require 'rgeo-geojson'
require 'mongoid'

# authentication
require 'devise'

# authorization
require 'cancancan'

# pagination
require 'kaminari'
# print formatting for e.g. hashes
require 'awesome_print'
# validator for json data
require 'json-schema'
# backgound-jobs
require 'delayed_job'
require 'delayed_job_active_record'

# REST-client
require 'faraday'
require 'faraday_middleware'

# simple logger
require 'logging'

# i18n for db
require 'globalize'

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

module DataCycleCore
  class << self
    mattr_accessor :breadcrumb_root_name
    self.breadcrumb_root_name = 'Dashboard'

    # :special_data_attributes: @deprecated: remove after APIv2 migrations
    # special data attributes are ignored by the standard json serializes and must be handled by the application itself
    mattr_accessor :special_data_attributes
    self.special_data_attributes = ['id', 'validity_period']

    mattr_accessor :internal_classification_attributes
    self.internal_classification_attributes = ['data_type']

    mattr_accessor :internal_data_attributes
    self.internal_data_attributes = ['date_created', 'date_modified', 'date_deleted', 'is_part_of'] + internal_classification_attributes

    mattr_accessor :asset_objects
    self.asset_objects = ['DataCycleCore::Asset', 'DataCycleCore::Image', 'DataCycleCore::Video', 'DataCycleCore::TextFile', 'DataCycleCore::Pdf', 'DataCycleCore::Audio']

    mattr_accessor :content_tables
    self.content_tables = ['things']

    mattr_accessor :allowed_api_strategies
    self.allowed_api_strategies = ['DataCycleCore::Api::MediaArchiveExternalSource']

    mattr_accessor :excluded_filter_classifications
    self.excluded_filter_classifications = ['Angebotszeitraum', 'Antwort', 'Datei', 'Frage', 'Veranstaltungstermin', 'Website', 'Zeitleiste-Eintrag', 'Zitat', 'Öffnungszeit', 'Overlay', 'Publikations-Plan', 'Textblock']

    mattr_accessor :ui_language
    self.ui_language = :de

    mattr_accessor :notification_frequencies
    self.notification_frequencies = ['always', 'day', 'week']

    # autoload_last_filter?, life_cycle, releasable, overlay, container, publishing ...
    mattr_accessor :features
    self.features = {
      publication_schedule: {
        enabled: false
      },
      overlay: {
        enabled: false,
        attribute_keys: ['overlay']
      },
      releasable: {
        enabled: false,
        attribute_keys: [
          'release_status_id',
          'release_status_comment'
        ],
        classification_names: {
          valid: 'freigegeben',
          partner: 'beim Partner',
          review: 'in Review',
          archive: 'archiviert'
        }
      },
      life_cycle: {
        enabled: false
      },
      idea_collection: {
        enabled: false
      },
      container: {
        enabled: false
      },
      main_filter: {
        enabled: true,
        classification_alias_ids: ['Inhaltstypen']
      },
      advanced_filter: {
        enabled: true,
        classification_alias_ids: 'all',
        external_source: true,
        creator: true
      },
      geocode: {
        enabled: false,
        attribute_keys: []
      },
      gpx_converter: {
        enabled: true
      }
    }

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
    self.webhooks = {
      create: [],
      delete: [],
      update: []
    }

    # template directories
    mattr_accessor :template_path
    mattr_accessor :default_template_paths
    self.default_template_paths = []

    # location of import/download configs
    mattr_accessor :external_sources_path

    # obsolete: remove after projects initializer update
    mattr_accessor :allowed_content_api_classifications
    self.allowed_content_api_classifications = []

    mattr_accessor :image_validations
    self.image_validations = {}

    mattr_accessor :video_validations
    self.video_validations = {}

    mattr_accessor :default_map_position
    self.default_map_position = {
      longitude: 14.128417968749998,
      latitude: 47.41520280002081,
      zoom: 7
    }
  end

  def self.setup
    yield self
  end

  class Engine < ::Rails::Engine
    isolate_namespace DataCycleCore

    config.assets.version = '1.0'
    config.assets.precompile += ['data_cycle_core/*', 'location.svg', 'eml-datacycle.png', 'eml-datacycle-border.png', 'eml-logo.png', 'eml-user.jpg']

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

    config.to_prepare do
      Dir.glob(
        [
          Rails.root + 'app/decorators/**/*_decorator*.rb',
          Rails.root + 'app/extensions/**/*.rb'
        ]
      ).each do |c|
        require_dependency(c)
      end
    end
  end
end

require 'data_cycle_core/exceptions'
