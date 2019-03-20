# frozen_string_literal: true

module Translations
  module Backends
    # Backend which does absolutely nothing. (for testing)
    class Null
      include Backend

      def read(_locale, _options = nil)
      end

      def write(_locale, _value, _options = nil)
      end

      def self.configure(_)
      end
    end
  end
end
