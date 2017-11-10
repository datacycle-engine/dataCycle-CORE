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
require 'gretel-trails'

# support for forms
require 'simple_form'

# rendering json responses
require 'jbuilder'

require 'acts_as_paranoid'

require 'transproc/all'

module DataCycleCore
  class << self
    mattr_accessor :breadcrumb_root_name
    self.breadcrumb_root_name = 'Dashboard'

    # special data attributes are ignored by the standard json serializes and must be handled by the application itself
    mattr_accessor :special_data_attributes
    self.special_data_attributes = []

    mattr_accessor :internal_data_attributes
    self.internal_data_attributes = ['creator', 'data_pool', 'data_type', 'is_part_of']

    mattr_accessor :default_image_type
    self.default_image_type = nil

    mattr_accessor :default_place_type
    self.default_place_type = nil

    mattr_accessor :access_tokens
    self.access_tokens = []

    mattr_accessor :content_tables
    self.content_tables = ['creative_works', 'events', 'persons', 'places']

    mattr_accessor :ui_language
    self.ui_language = :de

    #webhooks
    mattr_accessor :webhooks
    self.webhooks = {
        :create => [],
        :delete => [],
        :update => []
    }
  end

  def self.setup
    yield self
  end

  module OutdoorActive
    mattr_accessor :content_template

    mattr_accessor :image_template

    def self.setup
      yield self
    end
  end

  module Jsonld
    mattr_accessor :content_template

    mattr_accessor :image_template

    def self.setup
      yield self
    end
  end

  class Engine < ::Rails::Engine
    isolate_namespace DataCycleCore

    config.assets.precompile += ['data_cycle_core/*']

    # use active_record as orm (!not mongoid)
    config.app_generators.orm = :active_record
    config.active_record.schema_format = :sql

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

    # load db-viewer only in development environment
    # if Rails.env == "development"
    #
    #   require 'rails_db'
    #   if Object.const_defined?('RailsDb')
    #     RailsDb.setup do |config|
    #       config.black_list_tables = ['spatial_ref_sys', 'ar_internal_metadata']
    #       #config.verify_access_proc = proc { |controller| controller.current_user.admin? }
    #     end
    #   end
    #
    # end

    # include rake_tasks
    rake_tasks do
      Dir[File.join(File.dirname(__FILE__),'tasks/*.rake')].each { |f| load f }
    end

    config.to_prepare do
      Dir.glob(Rails.root + "app/decorators/**/*_decorator*.rb").each do |c|
        require_dependency(c)
      end
    end

  end
end


JbuilderTemplate.class_eval do
  def content_partial!(partial, parameters)
    partials = [
      "#{parameters[:content].class.class_name.underscore}_#{parameters[:content].content_type.underscore}_#{partial}",
      "#{parameters[:content].class.class_name.underscore}_#{partial}",
      "content_#{partial}"
    ]

    partials.each_with_index do |partial, idx|
      begin
        return partial!(partial, parameters)
      rescue ActionView::MissingTemplate => e
        raise e if idx == partials.size - 1
      end
    end
  end
end

# add dateformat with fractional seconds
Time::DATE_FORMATS[:long_usec] = '%Y-%m-%d %H:%M:%S.%N %z'

Nokogiri::XML::Node.class_eval do
  def to_hash
    begin
      attributes_hash = attributes.map { |_, attribute|
        { attribute.name => attribute.value }
      }.reduce({}, &:merge).reject { |_, v|
        v.blank?
      }

      children_hash = children.map { |child|
        { child.name => child.to_hash }
      }.reject { |h|
        h.values.first.blank?
      }.group_by { |h|
        h.keys.first
      }.map { |k, v|
        Hash[k, v.size == 1 ? v.map(&:values).flatten.first : v.map(&:values).flatten]
      }.reduce({}, &:merge)

      if !attributes.empty? && children.empty?
        attributes_hash
      elsif attributes.empty? && !children.empty?
        children_hash
      elsif !attributes.empty? && !children.empty?
        if (attributes_hash.keys & children_hash.keys).empty?
          attributes_hash.merge(children_hash)
        else
          {
            'attributes' => attributes_hash,
            'children' => children_hash
          }
        end
      elsif is_a? Nokogiri::XML::Text
        text.strip
      elsif is_a? Nokogiri::XML::Element
        nil
      else
        binding.pry

        raise 'NotImplemented'
      end
    rescue => e
      binding.pry

      raise e
    end
  end
end


# patch for ActiveRecord, to allow fractional seconds to be saved for PostgreSQL tstzrange datatype
# TODO: remove if updated upstream
module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        class Range < Type::Value
          def serialize(value)
            if value.is_a?(::Range)
              from = type_cast_single_for_database(value.begin)
              to = type_cast_single_for_database(value.end)
              [
                '[',
                from.is_a?(Time) ? from.to_s(:long_usec) : from,
                ',',
                to.is_a?(Time) ? to.to_s(:long_usec) : to,
                value.exclude_end? ? ')' : ']'
              ].join('')
            else
              super
            end
          end
        end
      end
    end
  end
end
