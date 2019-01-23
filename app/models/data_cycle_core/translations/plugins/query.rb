# frozen_string_literal: true

module DataCycleCore
  module Translations
    module Plugins
      module Query
        extend DataCycleCore::Translations::Plugin

        # Applies query plugin to attributes.
        included_hook do |model_class, backend_class|
          include_query_module(model_class, backend_class) if options[:query]
        end

        private

        def include_query_module(model_class, backend_class)
          DataCycleCore::Translations::Plugins::ActiveRecord::Query.apply(names, model_class, backend_class)
        end
      end
    end
  end
end
