# frozen_string_literal: true

module DataCycleCore
  module OpeningTimeHelper
    def opening_time_time_definition
      {
        'type' => 'opening_time_time',
        'label' => t('opening_time.time', locale: DataCycleCore.ui_language)
      }
    end

    def opening_time_validity_period(validity_period)
      safe_join(
        validity_period.compact.map { |d| d.present? ? tag.b(l(d&.to_date, format: :edit, locale: DataCycleCore.ui_language)) : nil },
        " #{I18n.t('opening_time.valid_until', locale: DataCycleCore.ui_language)} "
      ).prepend("#{I18n.t('opening_time.valid_from', locale: DataCycleCore.ui_language)} ")
    end

    def opening_time_opening_hours(opening_times)
      safe_join([*(1..6), 0, 99].map { |v|
        safe_join(
          opening_times.filter { |o| o.dig(:rrules, 0, :validations, :day)&.include?(v) || (v == 99 && o[:holidays]) }
            .map do |o|
            safe_join([
              o.dig(:start_time, :time).present? ? tag.b(l(o.dig(:start_time, :time)&.in_time_zone, format: :time_only, locale: DataCycleCore.ui_language)) : nil,
              o.dig(:end_time, :time).present? ? tag.b("#{l(o.dig(:end_time, :time)&.in_time_zone, format: :time_only, locale: DataCycleCore.ui_language)} #{t('common.o_clock', locale: DataCycleCore.ui_language)}") : nil
            ].compact, ' - ').presence
          end,
          " #{t('common.and', locale: DataCycleCore.ui_language)} "
        ).presence
          &.prepend(tag.span("#{v == 99 ? t('opening_time.holiday', locale: DataCycleCore.ui_language) : t('date.day_names', locale: DataCycleCore.ui_language)[v]}: ", class: 'opening-time-day'))
      }.compact, tag.br)
    end
  end
end
