# frozen_string_literal: true

module DataCycleCore
  module TimeseriesHelper
    CHART_TYPE_OPTIONS = [
      'bar',
      'line',
      'scatter'
    ].freeze

    def time_series_date(definition, key = 'min')
      attribute = "date_#{key}"

      return unless definition&.dig('ui', 'show', 'timeseries')&.key?(attribute)

      ERB.new(definition.dig('ui', 'show', 'timeseries', attribute).to_s).result(binding).in_time_zone
    end

    def grouping_options(definition)
      default_options = {
        I18n.t('timeseries.grouping_options.other', locale: active_ui_locale) => [[
          "#{I18n.t('timeseries.grouping_options.default', locale: active_ui_locale)} (#{I18n.t('timeseries.grouping_options.other', locale: active_ui_locale)})",
          nil
        ]]
      }

      if definition&.dig('ui', 'show', 'timeseries')&.key?('groups')
        options = definition.dig('ui', 'show', 'timeseries', 'groups').to_h do |k, v|
          [
            I18n.t("timeseries.grouping_options.#{k}", locale: active_ui_locale),
            v.map! do |g|
              [
                "#{I18n.t("timeseries.grouping_options.#{g}", locale: active_ui_locale)} (#{I18n.t("timeseries.grouping_options.#{k}", locale: active_ui_locale)})",
                "#{k.underscore}_#{g.underscore}"
              ]
            end
          ]
        end
      else
        options = DataCycleCore::ApiRenderer::TimeseriesRenderer::DEFAULT_AGGREGATE_FUNCTIONS.to_h do |aggregate_function|
          [
            I18n.t("timeseries.grouping_options.#{aggregate_function.underscore}", locale: active_ui_locale),
            DataCycleCore::ApiRenderer::TimeseriesRenderer::DEFAULT_GROUPS.map do |group|
              [
                "#{I18n.t("timeseries.grouping_options.#{group.underscore}", locale: active_ui_locale)} (#{I18n.t("timeseries.grouping_options.#{aggregate_function.underscore}", locale: active_ui_locale)})",
                "#{aggregate_function.underscore}_#{group.underscore}"
              ]
            end
          ]
        end
      end

      config = { class: 'dc-chart-grouping-input', id: nil }

      return grouped_options_for_select(default_options.merge(options) { |_k, v1, v2| Array.wrap(v1).concat(Array.wrap(v2)) }, definition.dig('ui', 'show', 'timeseries', 'default_group') || 'avg_week'), **config
    end

    def chart_type_options(definition)
      options = definition&.dig('ui', 'show', 'timeseries')&.key?('chart_types') ? Array.wrap(definition.dig('ui', 'show', 'timeseries', 'chart_types')) : CHART_TYPE_OPTIONS
      options.unshift(CHART_TYPE_OPTIONS.first) if options.blank?

      return options_for_select(options.map { |g| [I18n.t("timeseries.chart_type_options.#{g || 'default'}", locale: active_ui_locale), g] }, definition&.dig('ui', 'show', 'timeseries', 'default_chart_type') || options.first), class: 'dc-chart-chart-type-input', id: nil
    end
  end
end
