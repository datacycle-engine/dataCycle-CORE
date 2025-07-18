# frozen_string_literal: true

module DataCycleCore
  module OpeningTimeHelper
    def opening_time_time_definition(readonly: false)
      base_def = {
        'type' => 'opening_time_time',
        'label' => t('opening_time.time', locale: active_ui_locale)
      }
      base_def['ui'] = { 'edit' => { 'readonly' => readonly } } if readonly
      base_def
    end

    def opening_time_validity_period(validity_period)
      safe_join(
        validity_period.compact.map { |d| d.present? ? tag.b(l(d&.in_time_zone&.to_date, format: :edit, locale: active_ui_locale)) : nil },
        " #{I18n.t('opening_time.valid_until', locale: active_ui_locale)} "
      ).prepend("#{I18n.t('opening_time.valid_from', locale: active_ui_locale)} ")
    end

    def opening_time_ex_dates(opening_times)
      extimes = opening_times
        .map { |o| o[:extimes]&.pluck(:time) }
        .flatten
        .compact
        .uniq
        .sort_by
        .map { |e| l(e.to_date, format: :edit, locale: active_ui_locale) }

      return if extimes.blank?

      tag.span(
        "(#{I18n.t('opening_time.except', locale: active_ui_locale)}: #{extimes.join(', ')})",
        class: 'opening-time-ex-times',
        data: {
          dc_tooltip: "#{I18n.t('opening_time.except', locale: active_ui_locale)}: #{extimes.join(', ')})"
        }
      )
    end

    def opening_time_opening_hours(opening_times)
      days = [*(1..6), 0]
      days.push(99) if opening_times.any? { |d| !d[:holidays].nil? }

      safe_join(days.filter_map do |v|
        (safe_join(
          opening_times.filter { |o| o.dig(:rrules, 0, :validations, :day)&.include?(v) || (v == 99 && o[:holidays]) }
            .sort_by { |o| o.dig(:start_time, :time) }
            .map do |o|
            safe_join([
              opening_time_opens(o)&.then { |st| tag.b(l(st, format: :time_only, locale: active_ui_locale)) },
              opening_time_closes(o)&.then { |st| tag.b("#{l(st, format: :time_only, locale: active_ui_locale)} #{t('common.o_clock', locale: active_ui_locale)}") }
            ].compact, ' - ').presence
          end,
          " #{t('common.and', locale: active_ui_locale)} "
        ).presence || tag.span(t('opening_time.closed', locale: active_ui_locale)))
          &.prepend(tag.span("#{v == 99 ? t('opening_time.holiday', locale: active_ui_locale) : t('date.day_names', locale: active_ui_locale)[v]}: ", class: 'opening-time-day'))
      end, tag.br)
    end

    def opening_time_opens(hash)
      DataCycleCore::Schedule.opening_time_with_duration(
        hash&.dig(:start_time, :time)&.in_time_zone(hash&.dig(:start_time, :zone))
      )
    end

    def opening_time_closes(hash)
      DataCycleCore::Schedule.opening_time_with_duration(
        hash&.dig(:start_time, :time)&.in_time_zone(hash&.dig(:start_time, :zone)),
        hash&.dig(:duration)
      )
    end
  end
end
