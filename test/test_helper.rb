# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

Bundler.require(*Rails.groups)

Dotenv::Railtie.load

require File.expand_path('../../test/dummy/config/environment.rb', __FILE__)
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

# load template, classifications for all tests
template_paths = [Rails.root.join('..', 'data_types'), Rails.root.join('..', 'data_types', 'custom')]
import_hash, duplicates = DataCycleCore::MasterData::ImportTemplates.check_for_duplicates(template_paths)
errors = DataCycleCore::MasterData::ImportTemplates.import_all_templates(template_hash: import_hash, validation: true)
puts 'template import error summary:'
ap errors
classification_yaml = Rails.root.join('..', 'data_types', 'classifications.yml')
DataCycleCore::MasterData::ImportClassifications.import(classification_yaml)

# DataCycleCore.content_tables.each do |item|
#   puts "Templates for #{item}"
#   ap "DataCycleCore::#{item.classify}".constantize.where(template: true).pluck(:template_name)
# end

# seed release table
if DataCycleCore::Release.count.zero?
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

if DataCycleCore::Role.count.zero?
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
