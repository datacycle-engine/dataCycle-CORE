# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class StatsDatabaseTest < DataCycleCore::TestCases::ActiveSupportTestCase
    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.create!(
        name: 'Stats Database Test System',
        identifier: 'stats-database-test-system',
        default_options: { 'locales' => ['de'] },
        config: {
          'import_config' => {
            'stats test' => { 'source_type' => 'stats_things' }
          }
        }
      )

      mongo_database = "#{DataCycleCore::Generic::Collection.database_name}_#{@external_source.id}"
      Mongoid.override_database(mongo_database)
      DataCycleCore::Generic::Collection.with(collection: 'stats_things') do |collection|
        collection.create!(external_id: 'stat-1', dump: { 'de' => { 'id' => 'stat-1', 'name' => 'Normal' } })
        collection.create!(external_id: 'stat-2', dump: { 'de' => { 'id' => 'stat-2', 'name' => 'Deleted', 'deleted_at' => Time.zone.now } })
        collection.create!(external_id: 'stat-3', dump: { 'de' => { 'id' => 'stat-3', 'name' => 'Archived', 'archived_at' => Time.zone.now } })
      end
    ensure
      Mongoid.override_database(nil)
    end

    after(:all) do
      DataCycleCore::MongoHelper.drop_mongo_db('stats-database-test-system')
    end

    test 'load_pg_stats returns sizes and counts per table' do
      stats = DataCycleCore::StatsDatabase.new.load_pg_stats

      assert_kind_of Hash, stats
      assert_includes stats.keys, 'things'
      assert_predicate stats['things']['total_size'], :present?
      assert_predicate stats['things']['count'], :present?
      assert_not_includes stats.keys, 'schema_migrations'
    end

    test 'load_all_stats populates postgres and import module data' do
      stats = DataCycleCore::StatsDatabase.new.load_all_stats

      assert_predicate stats.stat_update, :present?
      assert_equal ActiveRecord::Base.connection.current_database, stats.pg_name
      assert_predicate stats.pg_size, :positive?
      assert_includes stats.import_modules.keys, @external_source.id
      assert_equal 'Stats Database Test System', stats.import_modules.dig(@external_source.id, :name)
    end

    test 'load_mongo_stats aggregates collection counts for an external system' do
      data = DataCycleCore::StatsDatabase.new.load_mongo_stats(@external_source.id)

      assert_equal @external_source.id, data[:uuid]
      assert_equal 'Stats Database Test System', data[:name]
      assert_equal ['de'], data[:languages]
      assert_predicate data[:tables], :present?

      total, info = data[:tables]['Stats things']

      assert_equal '3', total
      assert_includes info, 'D: 1'
      assert_includes info, 'A: 1'
    end

    test 'schedule extracts upcoming runs from matching cron configuration' do
      schedule_config = [
        { 'type' => 'ignored' }, # skipped: has a type key
        { '0 2 * * *' => ["dc:import:append_job[#{@external_source.identifier},full]"] }
      ]

      result = DataCycleCore.stub(:schedule, schedule_config) do
        DataCycleCore::StatsDatabase.new.send(:schedule, @external_source)
      end

      assert_predicate result, :present?
      assert_operator result.size, :<=, 7
      assert_equal 'full', result.first[:mode]
      assert_predicate result.first[:timestamp], :present?
    end

    test 'schedule returns nothing when no cron job matches the external system' do
      schedule_config = [{ '0 2 * * *' => ['dc:import:append_job[some-other-system,full]'] }]

      result = DataCycleCore.stub(:schedule, schedule_config) do
        DataCycleCore::StatsDatabase.new.send(:schedule, @external_source)
      end

      assert_empty result
    end
  end
end
