# frozen_string_literal: true

module DataCycleCore
  module Warning
    class Common < Base
      class << self
        def invalid(_params, content, _context)
          !content.try(:is_valid?)
        end
      end
    end
  end
end
