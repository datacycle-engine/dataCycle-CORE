# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Report
    # Coverage for the abstract report base (Report::Base) and its CSV/TSV/JSON/XLSX
    # serializers, driven by minimal concrete subclasses.
    class BaseTest < DataCycleCore::TestCases::ActiveSupportTestCase
      # data is an ActiveRecord::Result (responds to #columns) -> non-PG headings branch.
      class ArReport < DataCycleCore::Report::Base
        def apply(_params)
          ActiveRecord::Base.connection.select_all("SELECT 'a' AS first, 'b' AS second")
        end
      end

      # data is a raw PG::Result (responds to #fields) -> PG headings branch.
      class PgReport < DataCycleCore::Report::Base
        def apply(_params)
          ActiveRecord::Base.connection.raw_connection.exec('SELECT 1 AS num')
        end
      end

      def params
        { key: 'my_report' }
      end

      test 'apply must be implemented by subclasses' do
        assert_raises(NotImplementedError) { DataCycleCore::Report::Base.new }
      end

      test 'available_params must be implemented by subclasses' do
        assert_raises(NotImplementedError) { ArReport.new(params:).available_params }
      end

      test 'to_csv renders headings and rows separated by semicolons' do
        body, headers = ArReport.new(params:, locale: 'de').to_csv

        assert_includes body, ';'
        assert_equal 'my_report.csv', headers[:filename]
        assert_equal 'text/csv', headers[:type]
      end

      test 'to_tsv renders tab-separated values' do
        body, headers = ArReport.new(params:).to_tsv

        assert_includes body, "\t"
        assert_equal 'my_report.tsv', headers[:filename]
        assert_equal 'text/tab-separated-values', headers[:type]
      end

      test 'to_json wraps the data under the configured key' do
        body, headers = ArReport.new(params:).to_json

        assert_equal 'my_report.json', headers[:filename]
        assert_equal 'application/json', headers[:type]
        assert_includes body, 'my_report'
      end

      test 'to_xlsx produces a workbook stream' do
        body, headers = ArReport.new(params:).to_xlsx

        assert headers[:filename].end_with?('.xlsx')
        assert_predicate body, :present?
      end

      test 'falls back to a default filename and reads PG result fields' do
        body, headers = PgReport.new(params: {}).to_csv

        assert_equal 'report.csv', headers[:filename]
        assert_includes body, 'num'
      end
    end
  end
end
