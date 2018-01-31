require 'pry'

# Configure Rails Environment
ENV['RAILS_ENV'] = 'test'

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
cw_path = Rails.root.join('..', 'data_types', 'creative_works', '*.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(cw_path, DataCycleCore::CreativeWork, false)
place_path = Rails.root.join('..', 'data_types', 'places', '*.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(place_path, DataCycleCore::Place, false)
person_path = Rails.root.join('..', 'data_types', 'persons', '*.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(person_path, DataCycleCore::Person, false)
event_path = Rails.root.join('..', 'data_types', 'events', '*.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(event_path, DataCycleCore::Event, false)

cwc_path = Rails.root.join('..', 'data_types', 'creative_works_custom', '*.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(cwc_path, DataCycleCore::CreativeWork, false)

classification_yaml = Rails.root.join('..', 'data_types', 'classifications.yml')
DataCycleCore::MasterData::ImportClassifications.new.import(classification_yaml)

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
