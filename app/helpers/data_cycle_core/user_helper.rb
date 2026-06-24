# frozen_string_literal: true

module DataCycleCore
  module UserHelper
    def user_additional_tile_attribute_value(key, value)
      return value unless value.acts_like?(:time) || key.end_with?('_at')
      return value if (v = value.try(:in_time_zone)).blank?

      l(v, locale: active_ui_locale, format: :edit)
    end

    def user_edit_roles(user)
      roles = DataCycleCore::Role.accessible_by(current_ability).order(:rank).to_a
      roles << user.role unless user.role.nil? || roles.include?(user.role)
      roles.sort_by!(&:rank)

      roles.map { |role| role.to_select_option(active_ui_locale).to_option_for_select }
    end
  end
end
