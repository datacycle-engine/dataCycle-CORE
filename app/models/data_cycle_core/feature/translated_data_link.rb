# frozen_string_literal: true

module DataCycleCore
  module Feature
    class TranslatedDataLink < Base
      extend DataCycleCore::UiLocaleHelper

      class << self
        def locales
          if configuration&.dig('locales').present?
            available_locales_with_names.slice(*configuration['locales'].map(&:to_sym)).invert
          else
            available_locales_with_names.slice(*DataCycleCore.ui_locales.map(&:to_sym)).invert
          end
        end
      end
    end
  end
end
