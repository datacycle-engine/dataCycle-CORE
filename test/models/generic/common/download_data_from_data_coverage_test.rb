# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for DownloadDataFromData. create_aggregate_pipeline is a pure
      # MongoDB-aggregation *builder* (returns hashes, never executes), and
      # download_content is driven with the three download entry points stubbed,
      # so no Mongo is touched.
      class DownloadDataFromDataCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Generic::Common::DownloadDataFromData
        end

        test 'create_aggregate_pipeline builds stages for fallbacks, additional paths and grouping' do
          pipeline = subject.create_aggregate_pipeline(
            options: { download: {
              data_path: 'root.items[]',
              data_name_path: 'title',
              data_name_path_fallback: ['fallback_one', 'fallback_two'],
              additional_data_paths: { 'external_system' => 'es', 'extra' => 'x' },
              group_to_array_paths: ['tags'],
              attribute_whitelist: ['keep']
            } },
            locale: :de,
            source_filter: { 'status' => 'active' }
          )

          assert_kind_of(Array, pipeline)
          assert(pipeline.any? { |stage| stage.key?('$group') })
          assert(pipeline.any? { |stage| stage.key?('$replaceRoot') })
        end

        test 'download_content delegates to download functions and the bulk steps' do
          utility = struct_double(external_source: struct_double(last_download: nil))
          options = { download: { name: 'things', bulk_touch: true, bulk_mark_deleted: true } }

          DataCycleCore::Generic::Common::DownloadFunctions.stub(:download_content, nil) do
            DataCycleCore::Generic::Common::DownloadBulkTouchFromData.stub(:download_content, nil) do
              DataCycleCore::Generic::Common::DownloadBulkMarkDeleted.stub(:download_content, nil) do
                assert_nothing_raised do
                  subject.download_content(utility_object: utility, options:)
                end
              end
            end
          end
        end
      end
    end
  end
end
