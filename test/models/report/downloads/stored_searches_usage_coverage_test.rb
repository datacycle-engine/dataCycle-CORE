# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Report
    module Downloads
      # Coverage for the StoredSearchesUsage downloads report. Building the report
      # runs the raw aggregate query (Report::Base#initialize calls #apply) against
      # the empty collections/activities tables, and translated_headings maps the
      # result columns to localized headings (the month-heading branch is exercised
      # via a stubbed result set).
      class StoredSearchesUsageCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        Subject = DataCycleCore::Report::Downloads::StoredSearchesUsage

        def report
          Subject.new(params: { by_month: 6, by_year: 2026 }, locale: 'de')
        end

        test 'apply runs the stored-searches query and exposes result columns' do
          assert_includes(report.data.columns, 'creator')
        end

        test 'translated_headings maps every column including the month heading' do
          report_instance = report
          report_instance.instance_variable_set(:@data, ActiveRecord::Result.new(['downloads_by_month', 'creator'], []))

          headings = report_instance.send(:translated_headings)

          assert_equal(2, headings.size)
        end
      end
    end
  end
end
