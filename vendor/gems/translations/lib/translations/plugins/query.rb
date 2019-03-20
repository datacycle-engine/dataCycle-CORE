# frozen_string_literal: true

module Translations
  module Plugins
    module Query
      extend Translations::Plugin

      # Applies query plugin to attributes.
      included_hook do |model_class, backend_class|
        include_query_module(model_class, backend_class) if options[:query]
      end

      private

      def include_query_module(model_class, backend_class)
        require 'translations/plugins/active_record/query'
        Translations::Plugins::ActiveRecord::Query.apply(names, model_class, backend_class)
      end
    end
  end
end
