# frozen_string_literal: true

module DataCycleCore
  module Warning
    class Bild < Base
      class << self
        def translation_missing(_params, content, _context)
          content.translated_locales.exclude?(I18n.locale)
        end
      end
    end
  end
end
