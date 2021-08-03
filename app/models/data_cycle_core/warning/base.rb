# frozen_string_literal: true

module DataCycleCore
  module Warning
    class Base
      class << self
        def message(method_name, _content, _context)
          {
            path: "#{name.underscore.tr('/', '.')}.#{method_name}"
          }
        end
      end
    end
  end
end
