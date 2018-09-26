# frozen_string_literal: true

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

unless (ENV['TEST_COVERAGE'] || '1').to_i.zero?
  require 'simplecov'
  SimpleCov.start 'rails'
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
    def self.load_classifications(paths)
      paths.map do |path|
        DataCycleCore::MasterData::ImportClassifications.import(path)
      end
    end

    def self.load_templates(paths)
      import_hash, _duplicates = DataCycleCore::MasterData::ImportTemplates.check_for_duplicates(paths)
      errors = DataCycleCore::MasterData::ImportTemplates.import_all_templates(template_hash: import_hash, validation: true)

      return if errors.values.reduce(&:merge).blank?

      puts 'template import error summary:'
      ap errors
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
      DataCycleCore::User.where(email: 'tester@datacycle.at').first_or_create({
        given_name: 'Tester',
        external: false,
        password: 'dont care',
        role_id: DataCycleCore::Role.find_by(rank: 5).id
      })
    end

    def self.create_user_group
      if DataCycleCore::UserGroup.find_by(name: 'Administrators').blank?
        user_group = DataCycleCore::UserGroup.find_or_create_by(name: 'Administrators')
        DataCycleCore::UserGroupUser.create!(
          user_group_id: user_group.id,
          user_id: DataCycleCore::User.find_by(email: 'admin@datacycle.at').id
        )
      end
      return if DataCycleCore::UserGroup.find_by(name: 'Users').present?
      user_group = DataCycleCore::UserGroup.find_or_create_by(name: 'Users')
      DataCycleCore::UserGroupUser.create!(
        user_group_id: user_group.id,
        user_id: DataCycleCore::User.find_by(email: 'tester@datacycle.at').id
      )
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
    Rails.root.join('..', 'data_types'),
    Rails.root.join('..', 'data_types', 'attributes'),
    Rails.root.join('..', 'data_types', 'custom')
  ]
)
DataCycleCore::TestPreparations.load_user_roles
DataCycleCore::TestPreparations.create_user
DataCycleCore::TestPreparations.create_user_group
