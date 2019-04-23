# frozen_string_literal: true

module DataCycleCore
  module Warning
    class Common < Base
      class << self
        def invalid(_params, content, _context)
          !content.try(:is_valid?)
        end

        def translation_missing(_params, content, _context)
          content.translated_locales.exclude?(I18n.locale)
        end
      end
    end
  end
end
