# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Generic
    module Common
      # Coverage for DownloadBulkMarkDeletedFromEndpoint.data_id (pure) and the
      # stubbed delegation to DownloadFunctions.bulk_mark_deleted.
      class DownloadBulkMarkDeletedFromEndpointCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        def subject
          DataCycleCore::Generic::Common::DownloadBulkMarkDeletedFromEndpoint
        end

        test 'data_id returns non-hash items unchanged' do
          assert_equal('plain', subject.data_id({ download: {} }, 'plain'))
        end

        test 'data_id builds the prefixed external key from the configured path' do
          options = { download: { external_key_path: 'a.b', external_key_prefix: 'pre-' } }

          assert_equal('pre-value', subject.data_id(options, { 'a' => { 'b' => 'value' } }))
        end

        test 'data_id returns nil when the external_key_path is blank' do
          assert_nil(subject.data_id({ download: {} }, { 'a' => 1 }))
        end

        test 'download_content delegates to DownloadFunctions.bulk_mark_deleted' do
          DataCycleCore::Generic::Common::DownloadFunctions.stub(:bulk_mark_deleted, nil) do
            assert_nothing_raised do
              subject.download_content(utility_object: struct_double(id: 'x'), options: { download: {} })
            end
          end
        end
      end
    end
  end
end
