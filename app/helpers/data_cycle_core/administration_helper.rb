# frozen_string_literal: true

module DataCycleCore
  module AdministrationHelper
    def import_data_time(timestamp)
      timestamp.then { |t| t.is_a?(Time) ? l(t, locale: active_ui_locale, format: :edit) : t }
    end
  end
end
