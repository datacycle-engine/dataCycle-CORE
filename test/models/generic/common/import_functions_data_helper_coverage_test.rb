# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for the rescue/instrument branches of ImportFunctions'
      # process_step / process_syncs (driven by a transformation that raises).
      class ImportFunctionsDataHelperCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Generic::Common::ImportFunctions
        end

        def utility_object
          source = struct_double(id: '00000000-0000-0000-0000-000000000001', name: 'Import ES', identifier: 'import-es')
          Class.new {
            define_method(:external_source) { source }
            define_method(:step_config) { |config| (config || {}).with_indifferent_access }
          }.new
        end

        test 'process_step instruments and re-raises transformation failures' do
          raising = ->(_data) { raise 'transform boom' }

          assert_raises(RuntimeError) do
            subject.process_step(
              utility_object:,
              raw_data: { 'external_key' => 'k1' },
              transformation: raising,
              default: { template: 'POI' },
              config: {}
            )
          end
        end

        test 'process_syncs instruments and re-raises transformation failures' do
          raising = ->(_data) { raise 'transform boom' }

          assert_raises(RuntimeError) do
            subject.process_syncs(
              utility_object:,
              raw_data: { 'external_key' => 'k1' },
              transformation: raising,
              default: { template: 'POI' },
              config: {}
            )
          end
        end
      end
    end
  end
end
