# frozen_string_literal: true

module DataCycleCore
  module Translation
    module Backends
      class << self
        def load_backend(backend)
          return backend if backend.is_a?(::Module)
          DataCycleCore::Translation::Translation.get_class_from_key(self, backend)
        end
      end
    end
  end
end
