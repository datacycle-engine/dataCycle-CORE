# frozen_string_literal: true

module Translations
  module Backend
    module OrmDelegator
      def for(model_class)
        namespace = name.split('::')
        if model_class < ::ActiveRecord::Base # rubocop:disable Style/GuardClause
          require_backend(namespace.last.underscore)
          const_get(namespace.insert(-2, 'ActiveRecord').join('::'))
        else
          raise ArgumentError, "#{namespace.last} backend can only be used by ActiveRecord"
        end
      end

      private

      def require_backend(backend)
        orm_backend = "translations/backends/active_record/#{backend}"
        require orm_backend
      rescue LoadError => e
        raise unless /#{orm_backend}/.match?(e.message)
      end
    end
  end
end
