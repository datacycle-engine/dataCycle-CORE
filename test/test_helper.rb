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

    def self.load_release_statuses
      return unless DataCycleCore::Release.count.zero?

      DataCycleCore::Release.create!(
        release_code: 0,
        release_text: 'freigegeben'
      )
      DataCycleCore::Release.create!(
        release_code: 1,
        release_text: 'beim Partner'
      )
      DataCycleCore::Release.create!(
        release_code: 2,
        release_text: 'in Bearbeitung'
      )
      DataCycleCore::Release.create!(
        release_code: 3,
        release_text: 'in Review'
      )
      DataCycleCore::Release.create!(
        release_code: 4,
        release_text: 'Draft'
      )
      DataCycleCore::Release.create!(
        release_code: 10,
        release_text: 'gesperrt'
      )
    end

    def self.load_user_roles
      return unless DataCycleCore::Role.count.zero?

      DataCycleCore::Role.create!(
        rank: 0,
        name: 'guest'
      )
      DataCycleCore::Role.create!(
        rank: 1,
        name: 'external_partner'
      )
      DataCycleCore::Role.create!(
        rank: 2,
        name: 'standard'
      )
      DataCycleCore::Role.create!(
        rank: 3,
        name: 'editor_market_office'
      )
      DataCycleCore::Role.create!(
        rank: 4,
        name: 'basic_editor'
      )
      DataCycleCore::Role.create!(
        rank: 5,
        name: 'super_editor'
      )
      DataCycleCore::Role.create!(
        rank: 10,
        name: 'admin'
      )
    end

    def self.create_user
      return if DataCycleCore::User.find_by(given_name: 'Ad', family_name: 'Ministrator', email: 'admin@datacycle.at').present?
      DataCycleCore::User.create!(
        given_name:   'Ad',
        family_name:  'Ministrator',
        email:        'admin@datacycle.at',
        admin:        true,
        password:     '3amMQf74vp7Zpfdi',
        role_id:      DataCycleCore::Role.find_by(rank: 10)&.id
      )
    end

    def self.create_user_group
      return if DataCycleCore::UserGroup.find_by(name: 'Administrators').present?
      user_group = DataCycleCore::UserGroup.find_or_create_by(name: 'Administrators')
      DataCycleCore::UserGroupUser.create!(
        user_group_id: user_group.id,
        user_id: DataCycleCore::User.find_by(email: 'admin@datacycle.at').id
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
    Rails.root.join('..', 'data_types', 'custom')
  ]
)
DataCycleCore::TestPreparations.load_release_statuses
DataCycleCore::TestPreparations.load_user_roles
DataCycleCore::TestPreparations.create_user
DataCycleCore::TestPreparations.create_user_group
