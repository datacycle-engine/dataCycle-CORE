# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

unless (ENV['TEST_COVERAGE'] || '1').to_i.zero?
  require 'simplecov'
  SimpleCov.start 'rails' do
    # exclude cache folder for gitlab-ci
    add_filter '/cache/'
  end
  SimpleCov.at_exit do
    puts "\n"

    SimpleCov.result.format!

    puts "\nCOVERAGE: " \
      "#{(100 * SimpleCov.result.covered_lines.to_f / SimpleCov.result.total_lines.to_f).round(2)}% " \
      "(#{SimpleCov.result.covered_lines} / #{SimpleCov.result.total_lines} LOC)"
  end
end

Bundler.require(*Rails.groups)

Dotenv::Railtie.load

require File.expand_path('../test/dummy/config/environment.rb', __dir__)
# ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
# ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)
# ActiveRecord::Migration.maintain_test_schema!
require 'rails/test_help'

# Filter out Minitest backtrace while allowing backtrace from other libraries
# to be shown.
Minitest.backtrace_filter = Minitest::BacktraceFilter.new

# # Load fixtures from the engine
# if ActiveSupport::TestCase.respond_to?(:fixture_path=)
#   ActiveSupport::TestCase.fixture_path = File.expand_path("../fixtures", __FILE__)
#   ActionDispatch::IntegrationTest.fixture_path = ActiveSupport::TestCase.fixture_path
#   ActiveSupport::TestCase.file_fixture_path = ActiveSupport::TestCase.fixture_path + "/files"
#   ActiveSupport::TestCase.fixtures :all
# end

module DataCycleCore
  module TestPreparations
    extend DataCycleCore::Common
    EXCEPTED_ATTRIBUTES =
      {
        common: ['id', 'data_pool', 'data_type', 'publication_schedule', 'date_created', 'date_modified', 'date_deleted'],
        creative_work: [],
        event: [],
        organization: [],
        place: ['stars', 'source', 'regions', 'google_tags', 'xamoom_tags', 'feratel_types',
                'fontend_type', 'feratel_owners', 'feratel_topics', 'holiday_themes', 'poi_categories', 'tour_categories',
                'outdoor_active_tags', 'feratel_classifications', 'accommodation_categories', 'frontend_type'],
        person: []
      }.freeze

    @dummy_data_hash =
      {
        creative_works: {},
        events: {},
        organizations: {},
        places: {},
        persons: {}
      }

    def self.load_classifications(paths)
      paths.map do |path|
        DataCycleCore::MasterData::ImportClassifications.import(path)
      end
    end

    def self.load_templates(paths)
      errors, duplicates = DataCycleCore::MasterData::ImportTemplates.import_all(validation: true, template_paths: paths)
      if duplicates.present?
        puts 'INFO: the following templates had multiple definitions:'
        ap duplicates
      end
      return if errors.blank?
      puts 'the following errors were encountered during import:'
      ap errors
    end

    def self.load_dummy_data(paths)
      paths.each do |path|
        DataCycleCore.content_tables.each do |content_table_name|
          files = path + content_table_name + '*.json'

          file_names = Dir[files]
          file_names.each do |file_name|
            file_base_name = File.basename(file_name, '.json')
            json_data = JSON.parse(File.read(file_name))
            @dummy_data_hash[content_table_name.to_sym][file_base_name.to_sym] = json_data
          end
        end
      end
    end

    def self.load_user_roles
      DataCycleCore::Role.where(rank: 0).first_or_create({ name: 'guest' })
      DataCycleCore::Role.where(rank: 1).first_or_create({ name: 'external_partner' })
      DataCycleCore::Role.where(rank: 2).first_or_create({ name: 'standard' })
      DataCycleCore::Role.where(rank: 3).first_or_create({ name: 'editor_market_office' })
      DataCycleCore::Role.where(rank: 4).first_or_create({ name: 'basic_editor' })
      DataCycleCore::Role.where(rank: 5).first_or_create({ name: 'super_editor' })
      DataCycleCore::Role.where(rank: 10).first_or_create({ name: 'admin' })
      DataCycleCore::Role.where(rank: 99).first_or_create({ name: 'super_admin' })
    end

    def self.create_user
      DataCycleCore::User.where(email: 'admin@datacycle.at').first_or_create({
        given_name: 'Administrator',
        external: false,
        password: '3amMQf74vp7Zpfdi',
        role_id: DataCycleCore::Role.order('rank DESC').first.id
      })
    end

    def self.create_user_group
      return if DataCycleCore::UserGroup.find_by(name: 'Administrators').present?
      user_group = DataCycleCore::UserGroup.find_or_create_by(name: 'Administrators')
      DataCycleCore::UserGroupUser.create!(
        user_group_id: user_group.id,
        user_id: DataCycleCore::User.find_by(email: 'admin@datacycle.at').id
      )
    end

    def self.excepted_attributes(model = nil)
      return EXCEPTED_ATTRIBUTES[:common] + EXCEPTED_ATTRIBUTES[model.to_sym] if model.present?
      EXCEPTED_ATTRIBUTES[:common]
    end

    def self.load_dummy_data_hash(model, name)
      @dummy_data_hash.dig(model.to_sym, name.to_sym)
    end

    def self.data_set_object(model, template_name)
      object = data_cycle_object(model)
      template = object.where(template: true, template_name: template_name).first
      data_set = object.new
      data_set.schema = template.schema
      data_set.template_name = template.template_name
      data_set
    end
  end
end

DataCycleCore::TestPreparations.load_classifications(
  [
    Rails.root.join('..', 'data_types', 'classifications.yml')
  ]
)
DataCycleCore::TestPreparations.load_templates(
  [
    # Rails.root.join('..', 'data_types'),
    Rails.root.join('..', '..', 'config', 'data_definitions', 'basic'),
    Rails.root.join('..', '..', 'config', 'data_definitions', 'enhanced'),
    Rails.root.join('..', '..', 'config', 'data_definitions', 'media_archive'),
    Rails.root.join('..', '..', 'config', 'data_definitions', 'container'),
    Rails.root.join('..', 'data_types', 'attributes'),
    Rails.root.join('..', 'data_types', 'custom')
  ]
)
DataCycleCore::TestPreparations.load_dummy_data(
  [
    Rails.root.join('..', 'dummy_data')
  ]
)
DataCycleCore::TestPreparations.load_user_roles
DataCycleCore::TestPreparations.create_user
DataCycleCore::TestPreparations.create_user_group
