# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for ImportFunctions#delete_data (mixed in from ImportData).
      # Mongo is fully stubbed: the utility object's with_mongodb just yields and
      # source_object.with yields a placeholder mongo_item; the iterator returns a
      # criteria double and the data_processor a plain number, so no DB is touched.
      class ImportDataCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def logging_double
          Class.new {
            def phase_started(*) = nil
            def phase_finished(*) = nil
            def phase_failed(*) = nil
            def close = nil
          }.new
        end

        def criteria_double(size: 2, items: [])
          Class.new {
            def initialize(size, items)
              @size = size
              @items = items
            end

            def only(*) = self
            attr_reader :size

            def to_a = @items
          }.new(size, items)
        end

        def utility_object(logger:, mongo_item: Object.new, mode: :incremental)
          source = struct_double(id: '00000000-0000-0000-0000-000000000001', name: 'Import ES', identifier: 'import-es')
          src_obj = Class.new {
            def initialize(mongo_item) = (@mongo_item = mongo_item)
            def with(_source_type) = yield(@mongo_item)
          }.new(mongo_item)

          Class.new {
            define_method(:init_logging) { |_type| logger }
            define_method(:with_mongodb) { |&block| block.call }
            define_method(:locales) { [:de] }
            define_method(:step_label) { |_options| 'step' }
            define_method(:source_object) { src_obj }
            define_method(:source_type) { :things }
            define_method(:mode) { mode }
            define_method(:last_successful_try) { Time.zone.now }
            define_method(:external_source) { source }
            define_method(:step_name) { 'step name' }
          }.new
        end

        test 'delete_data iterates the stubbed source and reports the processor total' do
          filter_objects = []
          iterator = lambda { |filter_object:|
            filter_objects << filter_object
            criteria_double(size: 3)
          }
          processor = ->(utility_object:, raw_data:, locale:, options:) { 3 } # rubocop:disable Lint/UnusedBlockArgument

          DataCycleCore::Generic::Common::ImportFunctions.delete_data(
            utility_object: utility_object(logger: logging_double),
            iterator:,
            data_processor: processor,
            options: { import: { external_key_path: 'external_key' } }
          )

          assert_equal(1, filter_objects.size)
          assert_instance_of(DataCycleCore::Import::FilterObject, filter_objects.first)
        end

        test 'delete_data logs and re-raises processor failures' do
          iterator = ->(filter_object:) { criteria_double } # rubocop:disable Lint/UnusedBlockArgument
          processor = ->(**) { raise 'boom' }

          assert_raises(RuntimeError) do
            DataCycleCore::Generic::Common::ImportFunctions.delete_data(
              utility_object: utility_object(logger: logging_double),
              iterator:,
              data_processor: processor,
              options: {}
            )
          end
        end
      end
    end
  end
end
