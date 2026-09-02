# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  # Coverage for the Report::Downloads subclasses left below 90%. Report::Base#initialize
  # auto-runs #apply, so instantiating each report exercises its query builder; the results
  # run over the (mostly empty) activities/collections tables and come back as an
  # ActiveRecord::Result.
  class UnderNinetyReportsCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
    R = DataCycleCore::Report::Downloads

    before(:all) do
      @admin = DataCycleCore::User.find_by(email: 'admin@datacycle.at')
      @dzt_system = DataCycleCore::ExternalSystem.create!(name: 'DZT Cov', identifier: 'dzt', config: {})
      @thing = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { 'name' => 'report target' })
    end

    test 'WidgetUsage / WidgetUsageOverview run their base queries' do
      assert_kind_of ActiveRecord::Result, R::WidgetUsage.new(params: {}).data
      assert_kind_of ActiveRecord::Result, R::WidgetUsageOverview.new(params: { exclude_current_week: true }).data
      assert_kind_of ActiveRecord::Result, R::WidgetUsageOverview.new(params: { exclude_current_week: false }).data
    end

    test 'WidgetUsageBase builds the raw/overview/base SQL strings' do
      assert_kind_of String, R::WidgetUsageBase.raw_report_data_sql
      assert_kind_of String, R::WidgetUsageBase.raw_report_data_sql(exclude_current_week: true)
      assert_kind_of String, R::WidgetUsageBase.overview_sql
      assert_kind_of String, R::WidgetUsageBase.base_query(is_overview: false)
      assert_kind_of String, R::WidgetUsageBase.base_query(is_overview: true, exclude_current_week: true)
    end

    test 'MyWatchListsOverview lists accessible watch lists' do
      assert_kind_of ActiveRecord::Result, R::MyWatchListsOverview.new(current_user: @admin).data
    end

    test 'DztReport runs when a dzt external system exists' do
      assert_kind_of ActiveRecord::Result, R::DztReport.new(params: { by_year: 2026, by_month: 7 }).data
    end

    test 'Content report runs for an existing thing' do
      assert_kind_of ActiveRecord::Result, R::Content.new(params: { thing_id: @thing.id }).data
    end
  end
end
