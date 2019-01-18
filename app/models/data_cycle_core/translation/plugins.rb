# frozen_string_literal: true

module DataCycleCore
  module Translation
    module Plugins
      class << self
        def load_plugin(plugin)
          Translation.get_class_from_key(self, plugin)
        end
      end
    end
  end
end
