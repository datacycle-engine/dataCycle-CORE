# frozen_string_literal: true

module DataCycleCore
  module AdministrationHelper
    def import_data_time(timestamp)
      timestamp.then { |t| t.is_a?(Time) ? l(t, locale: active_ui_locale, format: :edit) : t }
    end

    def active_duration(data, type)
      return if data.dig(:"last_#{type}_time").blank? && data.dig(:"last_#{type}_class") != 'primary-color'

      if data.dig(:"last_#{type}_class") == 'primary-color'
        start_time = data.dig(:"last_#{type}")
        end_time = Time.zone.now
      else
        start_time = Time.zone.now
        end_time = Time.zone.now + data.dig(:"last_#{type}_time")
      end

      " (#{distance_of_time_in_words(start_time, end_time, locale: active_ui_locale)})"
    end

    def timestamp_tooltip(data, type)
      capture do
        timestamp = import_data_time(data.dig(:"last_#{type}"))
        next if timestamp.blank?

        concat(tag.b("#{type.titleize}: "))
        concat(timestamp)
        concat(active_duration(data, type))
      end
    end
  end
end
