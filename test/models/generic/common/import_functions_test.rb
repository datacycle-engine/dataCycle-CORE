# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DcImportFunctionsRecordingLogger
    attr_reader :calls

    def initialize
      @calls = []
    end

    def method_missing(name, *args)
      @calls << [name, *args]
    end

    def respond_to_missing?(_name, _include_private = false)
      true
    end
  end

  DcImportFunctionsDummyUtilityObject = Struct.new(:logger) do
    def init_logging(_type)
      logger
    end

    def step_label(_options)
      'dummy step'
    end
  end

  class GenericCommonImportFunctionsTest < DataCycleCore::TestCases::ActiveSupportTestCase
    SUBJECT = DataCycleCore::Generic::Common::ImportFunctions

    before(:all) do
      @external_source = DataCycleCore::ExternalSystem.create!(
        name: 'Import Functions Test System',
        identifier: 'import-functions-test-system',
        config: {
          'import_config' => {
            'functions test' => {
              'source_type' => 'ift_things',
              'import_strategy' => 'DataCycleCore::Generic::Common::ImportContents'
            }
          }
        }
      )
    end

    after(:all) do
      DataCycleCore::MongoHelper.drop_mongo_db('import-functions-test-system')
    end

    def utility_object(source_type, locales: [:de])
      DataCycleCore::Generic::ImportObject.new(
        external_source: @external_source,
        locales:,
        import: {
          source_type:,
          name: 'functions test',
          import_strategy: 'DataCycleCore::Generic::Common::ImportContents'
        }
      )
    end

    def seed_item(object, external_id, dump)
      object.with_mongodb do
        object.source_object.with(object.source_type) do |mongo_item|
          item = mongo_item.find_or_initialize_by(external_id:)
          item.dump = dump
          item.save!
        end
      end
    end

    def collecting_processor(processed)
      lambda do |utility_object:, raw_data:, locale:, options:| # rubocop:disable Lint/UnusedBlockArgument
        processed << { raw_data:, locale: }
      end
    end

    def legacy_iterator
      ->(mongo_item, _locale, source_filter) { mongo_item.where(source_filter) }
    end

    test 'import_contents dispatches to import_sequential without iteration_strategy' do
      called = []
      collector = ->(**kwargs) { called << kwargs }

      SUBJECT.stub(:import_sequential, collector) do
        SUBJECT.import_contents(utility_object: :uo, iterator: :it, data_processor: :dp, options: {})
      end

      assert_equal [{ utility_object: :uo, iterator: :it, data_processor: :dp, options: {} }], called
    end

    test 'import_contents dispatches to the configured iteration_strategy' do
      called = []
      collector = ->(**kwargs) { called << kwargs }
      options = { iteration_strategy: 'import_all' }

      SUBJECT.stub(:import_all, collector) do
        SUBJECT.import_contents(utility_object: :uo, iterator: :it, data_processor: :dp, options:)
      end

      assert_equal [{ utility_object: :uo, iterator: :it, data_processor: :dp, options: }], called
    end

    test 'import_sequential processes all mongo items per locale' do
      object = utility_object('ift_sequential')
      seed_item(object, 'seq-1', { 'de' => { 'id' => 'seq-1', 'name' => 'eins' } })
      seed_item(object, 'seq-2', { 'de' => { 'id' => 'seq-2', 'name' => 'zwei' } })
      processed = []

      SUBJECT.import_sequential(
        utility_object: object,
        iterator: legacy_iterator,
        data_processor: collecting_processor(processed),
        options: { import: { name: 'sequential' } }
      )

      assert_equal 2, processed.size
      assert_equal [:de], processed.pluck(:locale).uniq
      assert_equal ['eins', 'zwei'], processed.map { |p| p[:raw_data]['name'] }.sort
    end

    test 'import_sequential skips deleted items and respects max_count' do
      object = utility_object('ift_sequential_max')
      seed_item(object, 'max-1', { 'de' => { 'id' => 'max-1', 'name' => 'eins' } })
      seed_item(object, 'max-2', { 'de' => { 'id' => 'max-2', 'name' => 'zwei', 'deleted_at' => Time.zone.now } })
      seed_item(object, 'max-3', { 'de' => { 'id' => 'max-3', 'name' => 'drei' } })
      processed = []

      SUBJECT.import_sequential(
        utility_object: object,
        iterator: legacy_iterator,
        data_processor: collecting_processor(processed),
        options: { import: { name: 'sequential' }, max_count: 1 }
      )

      assert_equal 1, processed.size
      assert_not_equal 'zwei', processed.first[:raw_data]['name']
    end

    test 'import_all processes the whole dump without locale' do
      object = utility_object('ift_all')
      seed_item(object, 'ia-1', { 'de' => { 'id' => 'ia-1', 'name' => 'eins' }, 'en' => { 'id' => 'ia-1', 'name' => 'one' } })
      processed = []

      SUBJECT.import_all(
        utility_object: object,
        iterator: legacy_iterator,
        data_processor: collecting_processor(processed),
        options: { import: { name: 'all' } }
      )

      assert_equal 1, processed.size
      assert_nil processed.first[:locale]
      assert_equal 'eins', processed.first[:raw_data].dig('de', 'name')
      assert_equal 'one', processed.first[:raw_data].dig('en', 'name')
    end

    test 'import_paging processes each external_id separately' do
      object = utility_object('ift_paging')
      seed_item(object, 'pg-1', { 'de' => { 'id' => 'pg-1', 'name' => 'eins' } })
      seed_item(object, 'pg-2', { 'de' => { 'id' => 'pg-2', 'name' => 'zwei' } })
      processed = []

      SUBJECT.import_paging(
        utility_object: object,
        iterator: legacy_iterator,
        data_processor: collecting_processor(processed),
        options: { import: { name: 'paging' } }
      )

      assert_equal 2, processed.size
      assert_equal [:de], processed.pluck(:locale).uniq
      assert_equal ['eins', 'zwei'], processed.map { |p| p[:raw_data]['name'] }.sort
    end

    test 'aggregate_to_collection calls iterator with locales and output_collection' do
      object = utility_object('ift_aggregate')
      received = []
      iterator = lambda do |mongo_item, locales, output_collection|
        received << { collection_name: mongo_item.collection_name, locales:, output_collection: }
        []
      end

      SUBJECT.aggregate_to_collection(
        utility_object: object,
        iterator:,
        options: { import: { name: 'aggregate', output_collection: 'aggregated_things' } }
      )

      assert_equal 1, received.size
      assert_equal [:de], received.first[:locales]
      assert_equal 'aggregated_things', received.first[:output_collection]
      assert_equal 'ift_aggregate', received.first[:collection_name].to_s
    end

    test 'aggregate_collection calls aggregation_function with merged options' do
      object = utility_object('ift_aggregate_fn')
      received = []
      aggregation_function = lambda do |mongo_item, logging, utility_object, options|
        received << { mongo_item:, logging:, utility_object:, options: }
        []
      end

      SUBJECT.aggregate_collection(
        object,
        aggregation_function,
        { import: { name: 'aggregate' }, download: { name: 'download step' } }
      )

      assert_equal 1, received.size
      assert_equal object, received.first[:utility_object]
      assert_equal 'download step', received.first[:options][:download_name]
      assert_equal 'ift_aggregate_fn', received.first[:options][:phase_name].to_s
    end

    test 'logging_without_mongo returns processor result and logs phases' do
      logger = DcImportFunctionsRecordingLogger.new
      dummy_object = DcImportFunctionsDummyUtilityObject.new(logger)
      received = []
      data_processor = lambda do |utility_object, options|
        received << [utility_object, options]
        7
      end

      result = SUBJECT.logging_without_mongo(utility_object: dummy_object, data_processor:, options: { import: { name: 'plain' } })

      assert_equal 7, result
      assert_equal [[dummy_object, { import: { name: 'plain' } }]], received
      assert_equal [:phase_started, 'dummy step'], logger.calls.first

      phase_finished = logger.calls.find { |call| call[0] == :phase_finished }

      assert_equal 'dummy step', phase_finished[1]
      assert_equal 7, phase_finished[2]
      assert_equal [:close], logger.calls.last
    end

    test 'import_sequential supports the aggregate iterator type' do
      object = utility_object('ift_seq_aggregate')
      seed_item(object, 'agg-1', { 'de' => { 'id' => 'agg-1', 'name' => 'eins' } })
      processed = []
      aggregate_iterator = ->(mongo_item, _locale, _source_filter) { mongo_item.collection.aggregate([{ '$match' => {} }]) }

      SUBJECT.import_sequential(
        utility_object: object,
        iterator: aggregate_iterator,
        data_processor: collecting_processor(processed),
        options: { import: { name: 'sequential', iterator_type: 'aggregate' } }
      )

      assert_equal 1, processed.size
    end

    test 'import_sequential logs a failed phase and re-raises processor errors' do
      object = utility_object('ift_seq_error')
      seed_item(object, 'serr-1', { 'de' => { 'id' => 'serr-1', 'name' => 'eins' } })
      failing = ->(**) { raise 'processor boom' }

      ActiveSupport::Notifications.stub(:instrument, ->(*_args, **_kwargs, &block) { block&.call }) do
        assert_raises(RuntimeError) do
          SUBJECT.import_sequential(utility_object: object, iterator: legacy_iterator, data_processor: failing, options: { import: { name: 'sequential' } })
        end
      end
    end

    test 'import_all injects credential keys and logs partial progress' do
      object = utility_object('ift_all_credentials')
      object.with_mongodb do
        object.source_object.with(object.source_type) do |mongo_item|
          item = mongo_item.find_or_initialize_by(external_id: 'creds-1')
          item.dump = { 'de' => { 'id' => 'creds-1', 'name' => 'eins' } }
          item.external_system = { 'credential_keys' => ['k1'] }
          item.save!
        end
      end
      processed = []

      SUBJECT.stub(:logging_delta, 1) do
        SUBJECT.import_all(utility_object: object, iterator: legacy_iterator, data_processor: collecting_processor(processed), options: { import: { name: 'all' } })
      end

      assert_equal(['k1'], processed.first[:raw_data].dig('de', 'dc_credential_keys'))
    end

    test 'import_paging triggers garbage collection every ten items' do
      object = utility_object('ift_paging_gc')
      (1..10).each { |i| seed_item(object, "pgc-#{i}", { 'de' => { 'id' => "pgc-#{i}", 'name' => "name #{i}" } }) }
      processed = []

      SUBJECT.import_paging(utility_object: object, iterator: legacy_iterator, data_processor: collecting_processor(processed), options: { import: { name: 'paging' } })

      assert_equal 10, processed.size
    end
  end
end
