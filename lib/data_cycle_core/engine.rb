# rails essentials
require 'rails'
require 'sass-rails'
require 'turbolinks'
require 'jquery-rails'

# Databases
require 'pg'
require 'activerecord-postgis-adapter'
require 'acts_as_tree'
require 'rgeo'
require 'mongoid'

# authentication
require 'devise'

# authorization
require 'cancancan'

# foundation helper
require 'foundation-rails'
require 'foundation_rails_helper'
require 'devise-foundation-views'

# google material icons wrapper
require 'material_icons'
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

module DataCycleCore
  class << self
    mattr_accessor :breadcrumb_root_name
    self.breadcrumb_root_name = 'Dashboard'

    # special data attributes are ignored by the standard json serializes and must be handled by the application itself
    mattr_accessor :special_data_attributes
    self.special_data_attributes = ['id', 'validity_period', 'creator', 'last_updated_by']

    mattr_accessor :internal_data_attributes
    self.internal_data_attributes = ['date_created', 'date_modified', 'creator', 'data_type', 'data_pool', 'is_part_of', 'last_updated_by']

    mattr_accessor :access_tokens
    self.access_tokens = []

    mattr_accessor :asset_objects
    self.asset_objects = ['DataCycleCore::Asset', 'DataCycleCore::Image']

    mattr_accessor :content_tables
    self.content_tables = ['creative_works', 'events', 'persons', 'organizations', 'places']

    mattr_accessor :linked_tables
    self.linked_tables = ['users']

    mattr_accessor :allowed_api_strategies
    self.allowed_api_strategies = ['DataCycleCore::Api::MediaArchiveExternalSource']

    mattr_accessor :excluded_filter_classifications
    self.excluded_filter_classifications = ['Angebotszeitraum', 'Antwort', 'Datei', 'Frage', 'Veranstaltungstermin', 'Website', 'Zeitleiste-Eintrag', 'Zitat', 'Öffnungszeit', 'Overlay', 'Publikations-Plan', 'Textblock']

    mattr_accessor :excluded_new_item_objects
    self.excluded_new_item_objects = []

    mattr_accessor :ui_language
    self.ui_language = :de

    mattr_accessor :translatable_types
    self.translatable_types = ['DataCycleCore::Person', 'DataCycleCore::Organization', 'DataCycleCore::Place', 'DataCycleCore::Event']

    mattr_accessor :release_codes
    self.release_codes = {
      partner: 1,
      review: 3
    }

    mattr_accessor :notification_frequencies
    self.notification_frequencies = ['always', 'day', 'week']

    # features
    # autoload_last_filter?, life_cycle, releasable, overlay, container, publishing ...
    mattr_accessor :features
    self.features = {
      publication_schedule: {
        enabled: false
      },
      overlay: {
        enabled: false
      },
      releasable: {
        enabled: false
      },
      life_cycle: {
        enabled: false
      },
      container: {
        enabled: false,
        exluded: [],
        allowed: []
      }
    }

    # inheritable_attributes
    mattr_accessor :inheritable_attributes
    self.inheritable_attributes = ['validity_period']

    # embedded_objects in show
    mattr_accessor :linked_objects_page_size
    self.linked_objects_page_size = 5

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

    # available filter
    mattr_accessor :available_filters
    self.available_filters = {
      main: ['Inhaltstypen'],
      advanced: []
    }

    # obsolete: remove after projects initializer update
    mattr_accessor :allowed_content_api_classifications
    self.allowed_content_api_classifications = []

    # replace default_image_type + default_place_type with default_templates
    mattr_accessor :default_image_type
    self.default_image_type = 'Bild'

    mattr_accessor :default_place_type
    self.default_place_type = 'Örtlichkeit'

    mattr_accessor :default_templates
    self.default_templates = {
      images: 'Bild',
      places: 'Örtlichkeit',
      events: 'Event',
      persons: 'Person',
      organizations: 'Organization'
    }
  end

  def self.setup
    yield self
  end

  class Engine < ::Rails::Engine
    isolate_namespace DataCycleCore

    config.assets.version = '1.0'
    config.assets.precompile += ['data_cycle_core/*']

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
    # Do not halt callback chains when a callback returns false. Previous versions had true.
    ActiveSupport.halt_callback_chains_on_return_false = false
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
      Dir.glob(Rails.root + 'app/decorators/**/*_decorator*.rb').each do |c|
        require_dependency(c)
      end
    end
  end
end
