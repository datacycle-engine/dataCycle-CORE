# frozen_string_literal: true

module DataCycleCore
  module UserHelper
    USER_FILTER_SORTABLE = [
      'given_name',
      'family_name',
      'name',
      'email',
      'created_at'
    ].freeze

    def user_additional_tile_attribute_value(key, value)
      return value unless value.acts_like?(:time) || key.end_with?('_at')
      return value if (v = value.try(:in_time_zone)).blank?

      l(v, locale: active_ui_locale, format: :edit)
    end

    def user_filter_sortable
      USER_FILTER_SORTABLE.map do |s|
        {
          label: t("user_sortable.#{s}", default: s, locale: active_ui_locale),
          method: s.to_s
        }
      end
    end
  end
end
