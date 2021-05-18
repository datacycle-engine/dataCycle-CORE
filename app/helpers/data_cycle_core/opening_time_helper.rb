# frozen_string_literal: true

module DataCycleCore
  module OpeningTimeHelper
    def opening_time_time_definition
      {
        'type' => 'opening_time_time',
        'label' => t('opening_time.time', locale: DataCycleCore.ui_language)
      }
    end

    def opening_time_validity_perdiod(validity_perdiod)
      validity_perdiod.compact
        .map { |d| l(d&.to_date, format: :edit, locale: DataCycleCore.ui_language) }
        .join(" #{I18n.t('opening_time.valid_until', locale: DataCycleCore.ui_language)} ")
        .prepend("#{I18n.t('opening_time.valid_from', locale: DataCycleCore.ui_language)} ")
    end

    def opening_time_opening_hours(opening_times)
      [*(1..6), 0, 99].map { |v|
        opening_times.filter { |o| o.dig(:rrules, 0, :validations, :day)&.include?(v) || (v == 99 && o[:holidays]) }
          .map { |o| "<b>#{l(o.dig(:start_time, :time)&.in_time_zone, format: :time_only, locale: DataCycleCore.ui_language)&.delete_suffix(':00')&.delete_prefix('0')}</b>-<b>#{l(o.dig(:end_time, :time)&.in_time_zone, format: :time_only, locale: DataCycleCore.ui_language)&.delete_suffix(':00')&.delete_prefix('0')} #{t('common.o_clock', locale: DataCycleCore.ui_language)}</b>" }
          .join(" #{t('common.and', locale: DataCycleCore.ui_language)} ")
          .presence
          &.prepend("#{v == 99 ? t('opening_time.holiday', locale: DataCycleCore.ui_language) : t('date.abbr_day_names', locale: DataCycleCore.ui_language)[v]}: ")
      }.compact.concat.join('<br>').html_safe
    end
  end
end
