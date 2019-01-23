# frozen_string_literal: true

module DataCycleCore
  module Translations
    module Plugins
      class << self
        def load_plugin(plugin)
          DataCycleCore::Translations::Translation.get_class_from_key(self, plugin)
        end
      end
    end
  end
end
