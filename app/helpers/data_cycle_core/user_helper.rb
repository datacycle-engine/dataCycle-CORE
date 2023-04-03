# frozen_string_literal: true

module DataCycleCore
  module UserHelper
    def user_additional_tile_attribute_value(key, value)
      return value unless value.acts_like?(:time) || key.end_with?('_at')
      return value if (v = value.try(:in_time_zone)).blank?

      l(v, locale: active_ui_locale, format: :edit)
    end
  end
end
