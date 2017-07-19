# Configure Rails Environment
ENV["RAILS_ENV"] = "test"

require File.expand_path("../../test/dummy/config/environment.rb", __FILE__)
# ActiveRecord::Migrator.migrations_paths = [File.expand_path("../../test/dummy/db/migrate", __FILE__)]
# ActiveRecord::Migrator.migrations_paths << File.expand_path('../../db/migrate', __FILE__)
# ActiveRecord::Migration.maintain_test_schema!
require "rails/test_help"

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
cw_path = Rails.root.join('..','data_types','creative_works','*.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(cw_path, DataCycleCore::CreativeWork)
place_path = Rails.root.join('..','data_types','places','*.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(place_path, DataCycleCore::Place)
person_path = Rails.root.join('..','data_types','persons','*.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(person_path, DataCycleCore::Person)
cwc_path = Rails.root.join('..','data_types','creative_works_custom','*.yml')
DataCycleCore::MasterData::ImportTemplates.new.import(cwc_path, DataCycleCore::CreativeWork)

classification_yaml = Rails.root.join('..','data_types','classifications.yml')
DataCycleCore::MasterData::ImportClassifications.new.import(classification_yaml); nil
