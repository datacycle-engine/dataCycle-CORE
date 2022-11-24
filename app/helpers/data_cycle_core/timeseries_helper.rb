# frozen_string_literal: true

module DataCycleCore
  module TimeseriesHelper
    GROUPING_OPTIONS = [
      nil,
      'hour',
      'day',
      'week',
      'month',
      'year'
    ].freeze

    CHART_TYPE_OPTIONS = [
      'bar',
      'line',
      'scatter'
    ].freeze

    def grouping_options(definition)
      options = definition&.dig('ui', 'show', 'timeseries')&.key?('groups') ? Array.wrap(definition.dig('ui', 'show', 'timeseries', 'groups')) : GROUPING_OPTIONS
      options.unshift(GROUPING_OPTIONS.first) if options.blank?

      return options_for_select(options.map { |g| [I18n.t("timeseries.grouping_options.#{g || 'default'}", locale: active_ui_locale), g] }), disabled: !options.many?, class: 'dc-chart-grouping-input', id: nil
    end

    def chart_type_options(definition)
      options = definition&.dig('ui', 'show', 'timeseries')&.key?('chart_types') ? Array.wrap(definition.dig('ui', 'show', 'timeseries', 'chart_types')) : CHART_TYPE_OPTIONS
      options.unshift(CHART_TYPE_OPTIONS.first) if options.blank?

      return options_for_select(options.map { |g| [I18n.t("timeseries.chart_type_options.#{g || 'default'}", locale: active_ui_locale), g] }), disabled: !options.many?, class: 'dc-chart-chart-type-input', id: nil
    end
  end
end
