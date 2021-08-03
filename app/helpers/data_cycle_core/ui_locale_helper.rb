# frozen_string_literal: true

module DataCycleCore
  module UiLocaleHelper
    def active_ui_locale
      current_user&.ui_locale || DataCycleCore.ui_locales.first
    end
  end
end
