# frozen_string_literal: true

module DataCycleCore
  module Translation
    module Plugins
      module Query
        extend DataCycleCore::Translation::Plugin

        # Applies query plugin to attributes.
        included_hook do |model_class, backend_class|
          include_query_module(model_class, backend_class) if options[:query]
        end

        private

        def include_query_module(model_class, backend_class)
          DataCycleCore::Translation::Plugins::ActiveRecord::Query.apply(names, model_class, backend_class)
        end
      end
    end
  end
end
