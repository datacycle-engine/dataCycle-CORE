# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Report
    module Downloads
      # Coverage for the Popular downloads report. Building the report runs the raw
      # aggregate query (Report::Base#initialize calls #apply), and translated_headings
      # maps the resulting columns to localized headings - both run against the (empty)
      # activities table without any fixtures.
      class PopularCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
        Subject = DataCycleCore::Report::Downloads::Popular

        def report
          Subject.new(params: { limit: 5, by_month: 6, by_year: 2026 }, locale: 'de')
        end

        test 'apply runs the popular-downloads query and exposes result columns' do
          assert_includes report.data.columns, 'downloads_by_month'
        end

        test 'translated_headings returns one heading per result column' do
          report_instance = report

          headings = report_instance.send(:translated_headings)

          assert_equal report_instance.data.columns.size, headings.size
        end
      end
    end
  end
end
