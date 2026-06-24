# frozen_string_literal: true

require 'test_helper'
require 'rails/generators/test_case'
require 'generators/rails/data_migration/data_migration_generator'

module DataCycleCore
  class DataMigrationGeneratorTest < Rails::Generators::TestCase
    tests Rails::DataMigrationGenerator
    destination File.expand_path('../../../../tmp/data_migration_generator', __dir__)
    setup :prepare_destination

    test 'creates a data migration file with a camelized class name' do
      run_generator ['add_indexes']

      files = Dir.glob(File.join(destination_root, 'db', 'data_migrate', '*_add_indexes.rb'))

      assert_equal 1, files.size
      assert_match(/class AddIndexes < ActiveRecord::Migration/, File.read(files.first))
    end
  end
end
