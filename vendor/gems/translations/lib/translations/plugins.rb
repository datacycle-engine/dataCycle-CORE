# frozen_string_literal: true

module Translations
  module Plugins
    class << self
      def load_plugin(plugin)
        require "translations/plugins/#{plugin}"
        Translations.get_class_from_key(self, plugin)
      end
    end
  end
end
