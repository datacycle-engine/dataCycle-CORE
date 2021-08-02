# frozen_string_literal: true

module DataCycleCore
  module UiLocaleHelper
    def active_ui_locale
      current_user&.ui_locale || active_ui_locale
    end
  end
end
