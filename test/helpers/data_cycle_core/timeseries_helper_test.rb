# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class TimeseriesHelperTest < ActionView::TestCase
    include DataCycleCore::TimeseriesHelper
    include DataCycleCore::UiLocaleHelper

    test 'time_series_date returns nil when the timeseries date is not configured' do
      assert_nil time_series_date({})
      assert_nil time_series_date({ 'ui' => { 'show' => { 'timeseries' => {} } } })
    end

    test 'time_series_date evaluates the configured date expression' do
      definition = { 'ui' => { 'show' => { 'timeseries' => { 'date_min' => '2024-01-01' } } } }

      assert_equal Date.new(2024, 1, 1), time_series_date(definition, 'min').to_date
    end

    # chart_type_options / grouping_options return [options_html, html_options]
    # so they can be splatted into select_tag.
    test 'chart_type_options offers the default chart types' do
      html, options = chart_type_options(nil)

      assert_includes html, 'value="bar"'
      assert_includes html, 'value="line"'
      assert_includes html, 'value="scatter"'
      assert_includes html, 'selected'
      assert_equal 'dc-chart-chart-type-input', options[:class]
    end

    test 'chart_type_options honors a configured list of chart types' do
      definition = { 'ui' => { 'show' => { 'timeseries' => { 'chart_types' => ['line'] } } } }
      html = chart_type_options(definition).first

      assert_includes html, 'value="line"'
      assert_not_includes html, 'value="scatter"'
    end

    test 'grouping_options builds grouped select options with the default group selected' do
      html = grouping_options({}).first

      assert_includes html, '<optgroup'
      assert_includes html, 'value="sum_hour"'
      assert_includes html, 'value="avg_week"'
    end
  end
end
