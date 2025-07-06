# frozen_string_literal: true

module DataCycleCore
  module AdministrationHelper
    def import_data_time(timestamp)
      timestamp.then { |t| t.is_a?(Time) ? l(t, locale: active_ui_locale, format: :edit) : t }
    end

    def active_duration(data, type)
      return if data[:"last_#{type}_time"].blank? && data[:"last_#{type}_status"] != 'running'

      if data[:"last_#{type}_status"] == 'running'
        start_time = data[:"last_#{type}"]
        end_time = Time.zone.now
      else
        start_time = Time.zone.now
        end_time = Time.zone.now + data[:"last_#{type}_time"]
      end

      " (#{distance_of_time_in_words(start_time, end_time, locale: active_ui_locale)})"
    end

    def timestamp_tooltip(data, type)
      capture do
        timestamp = import_data_time(data[:"last_#{type}"])
        next if timestamp.blank?

        concat(tag.b("#{type.titleize}: "))
        concat(timestamp)
        concat(active_duration(data, type))
      end
    end

    def import_schedule(schedule)
      return if schedule.blank?

      value = schedule.map { |s|
        next unless s[:timestamp].is_a?(EtOrbi::EoTime)
        text = [l(s[:timestamp], locale: active_ui_locale, format: :edit)]
        args = []
        args << tag.b(t("dash_board.#{s[:mode]}", locale: active_ui_locale)) if s[:mode].present?
        args << tag.i(class: 'fa fa-bolt') if s[:inline].present?
        args << tag.i(s[:steps].join(', ')) if s[:steps].present?
        text << " (#{args.join(', ')})" if args.any?
        text.join(' ')
      }.concat

      value << '...'
      value.unshift(tag.b(t('dash_board.schedule', locale: active_ui_locale, count: schedule.size)))

      "<span class='import-schedule-tooltip'>#{value.join('<br>')}</span>"
    end
  end
end
