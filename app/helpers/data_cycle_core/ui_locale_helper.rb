# frozen_string_literal: true

module DataCycleCore
  module UiLocaleHelper
    def active_ui_locale
      current_user&.ui_locale || DataCycleCore.ui_locales.first
    end

    def translated_attribute_label(template_name, key, label)
      if template_name.present? && I18n.exists?("attribute_labels.#{template_name}.#{key}")
        I18n.t("attribute_labels.#{template_name}.#{key}", locale: active_ui_locale)
      elsif I18n.exists?("attribute_labels.#{key}")
        I18n.t("attribute_labels.#{key}", locale: active_ui_locale)
      else
        label
      end
    end
  end
end
