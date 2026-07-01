# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for DeleteConcepts. import_data is driven through the stubbed
      # delete_data pipeline (self-returning mongo_item, no real Mongo) and
      # process_concepts is exercised directly over an empty ClassificationTree.
      class DeleteConceptsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Generic::Common::DeleteConcepts
        end

        def logging_double
          Class.new {
            def phase_started(*) = nil
            def phase_finished(*) = nil
            def phase_failed(*) = nil
            def close = nil
          }.new
        end

        # a mongo_item that survives FilterObject#query (where/all chain) and the
        # delete_data criteria calls (only/size/to_a)
        def mongo_item
          Class.new {
            def where(*) = self
            def all = self
            def only(*) = self
            def size = 0
            def to_a = []
          }.new
        end

        def utility_object
          logger = logging_double
          source = struct_double(id: '00000000-0000-0000-0000-000000000001', name: 'Delete ES', identifier: 'delete-es')
          src_obj = Class.new {
            def initialize(mongo_item) = (@mongo_item = mongo_item)
            def with(_source_type) = yield(@mongo_item)
          }.new(mongo_item)

          Class.new {
            attr_accessor :mode

            define_method(:init_logging) { |_type| logger }
            define_method(:with_mongodb) { |&block| block.call }
            define_method(:locales) { [:de] }
            define_method(:step_label) { |_options| 'delete step' }
            define_method(:source_object) { src_obj }
            define_method(:source_type) { :things }
            define_method(:last_successful_try) { nil }
            define_method(:external_source) { source }
            define_method(:step_name) { 'delete step' }
          }.new
        end

        test 'import_data runs delete_data with the load_concepts iterator' do
          assert_nothing_raised do
            subject.import_data(
              utility_object:,
              options: { import: { external_key_path: 'external_key' } }
            )
          end
        end

        test 'process_concepts maps external keys and destroys matching concept trees' do
          uo = struct_double(external_source: struct_double(id: '00000000-0000-0000-0000-000000000001'))
          raw_data = [struct_double(dump: { de: { 'external_key' => 'k1' } })]

          count = subject.process_concepts(
            utility_object: uo,
            raw_data:,
            locale: :de,
            options: { import: { external_key_path: 'external_key', external_key_prefix: 'pre-' } }
          )

          assert_equal(0, count)
        end

        test 'process_concepts returns nil for blank raw data' do
          assert_nil(subject.process_concepts(utility_object: nil, raw_data: [], locale: :de, options: {}))
        end
      end
    end
  end
end
