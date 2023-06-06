# frozen_string_literal: true

module DataCycleCore
  module OpeningTimeHelper
    def opening_time_time_definition
      {
        'type' => 'opening_time_time',
        'label' => t('opening_time.time', locale: active_ui_locale)
      }
    end

    def opening_time_validity_period(validity_period)
      safe_join(
        validity_period.compact.map { |d| d.present? ? tag.b(l(d&.in_time_zone&.to_date, format: :edit, locale: active_ui_locale)) : nil },
        " #{I18n.t('opening_time.valid_until', locale: active_ui_locale)} "
      ).prepend("#{I18n.t('opening_time.valid_from', locale: active_ui_locale)} ")
    end

    def opening_time_ex_dates(opening_times)
      extimes = opening_times
        .map { |o| o[:extimes]&.map { |e| e[:time] } }
        .flatten
        .uniq
        .sort_by
        .map { |e| l(e.to_date, format: :edit, locale: active_ui_locale) }

      return if extimes.blank?

      tag.span(
        "(#{I18n.t('opening_time.except', locale: active_ui_locale)}: #{extimes.join(', ')})",
        class: 'opening-time-ex-times'
      )
    end

    def opening_time_opening_hours(opening_times)
      days = [*(1..6), 0]
      days.push(99) if opening_times.any? { |d| !d.dig(:holidays).nil? }

      safe_join(days.map { |v|
        (safe_join(
          opening_times.filter { |o| o.dig(:rrules, 0, :validations, :day)&.include?(v) || (v == 99 && o[:holidays]) }
            .sort_by { |o| o.dig(:start_time, :time) }
            .map do |o|
            safe_join([
              o.dig(:start_time, :time).present? ? tag.b(l(o.dig(:start_time, :time)&.in_time_zone, format: :time_only, locale: active_ui_locale)) : nil,
              o.dig(:end_time, :time).present? ? tag.b("#{l(o.dig(:end_time, :time)&.in_time_zone, format: :time_only, locale: active_ui_locale)} #{t('common.o_clock', locale: active_ui_locale)}") : nil
            ].compact, ' - ').presence
          end,
          " #{t('common.and', locale: active_ui_locale)} "
        ).presence || tag.span(t('opening_time.closed', locale: active_ui_locale)))
          &.prepend(tag.span("#{v == 99 ? t('opening_time.holiday', locale: active_ui_locale) : t('date.day_names', locale: active_ui_locale)[v]}: ", class: 'opening-time-day'))
      }.compact, tag.br)
    end
  end
end
