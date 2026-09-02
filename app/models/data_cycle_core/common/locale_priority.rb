# frozen_string_literal: true

module DataCycleCore
  module Common
    # sorting of locales by their position in I18n.available_locales
    module LocalePriority
      extend ActiveSupport::Concern

      # translations may exist for locales the tenant does not (or no longer) serves,
      # those sort last instead of raising on a nil comparison
      def locale_priority(locale)
        I18n.available_locales.index(locale&.to_sym) || I18n.available_locales.size
      end
    end
  end
end
