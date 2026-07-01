# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for the Cleanup import strategy. It uses logging_without_mongo,
      # so a lightweight utility-object double (no Mongo) is enough.
      class CleanupCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        # minimal logger accepting the phase_* / close calls made by init_logging
        def logging_double
          Class.new {
            def phase_started(*) = nil
            def phase_finished(*) = nil
            def close = nil
          }.new
        end

        def utility_object
          source = struct_double(id: '00000000-0000-0000-0000-000000000001', name: 'Cleanup ES', identifier: 'cleanup-es')
          logger = logging_double
          Class.new {
            define_method(:external_source) { source }
            define_method(:init_logging) { |_type| logger }
            define_method(:step_label) { |_options| 'cleanup step' }
          }.new
        end

        test 'process_content counts (and would destroy) orphaned dependent contents' do
          count = DataCycleCore::Generic::Common::Cleanup.process_content(
            utility_object,
            { import: { dependent_types: ['POI'] } }
          )

          assert_equal(0, count)
        end

        test 'import_data runs cleanup through logging_without_mongo' do
          assert_nothing_raised do
            DataCycleCore::Generic::Common::Cleanup.import_data(
              utility_object:,
              options: { import: { dependent_types: ['POI'] } }
            )
          end
        end
      end
    end
  end
end
