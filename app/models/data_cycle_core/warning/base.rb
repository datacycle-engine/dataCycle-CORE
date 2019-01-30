# frozen_string_literal: true

module DataCycleCore
  module Warning
    class Base
      class << self
        def message(method_name, _content, _context)
          I18n.t("#{name.underscore.tr('/', '.')}.#{method_name}", locale: DataCycleCore.ui_language)
        end
      end
    end
  end
end
