# frozen_string_literal: true

module Translations
  module Backends
    class << self
      def load_backend(backend)
        return backend if backend.is_a?(::Module)
        require "translations/backends/#{backend}"
        Translations.get_class_from_key(self, backend)
      end
    end
  end
end
