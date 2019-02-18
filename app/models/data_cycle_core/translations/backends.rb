# frozen_string_literal: true

module DataCycleCore
  module Translations
    module Backends
      class << self
        def load_backend(backend)
          return backend if backend.is_a?(::Module)
          DataCycleCore::Translations::Translation.get_class_from_key(self, backend)
        end
      end
    end
  end
end
