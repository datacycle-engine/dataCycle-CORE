# frozen_string_literal: true

module Translations
  module Backend
    module OrmDelegator
      def for(model_class)
        namespace = name.split('::')
        if Loaded::ActiveRecord && model_class < ::ActiveRecord::Base # rubocop:disable Style/GuardClause
          require_backend(namespace.last.underscore)
          const_get(namespace.insert(-2, 'ActiveRecord').join('::'))
        else
          raise ArgumentError, "#{namespace.last} backend can only be used by ActiveRecord or Sequel models"
        end
      end

      private

      def require_backend(backend)
        orm_backend = "translations/backends/#{backend}"
        require orm_backend
      rescue LoadError => e
        raise unless e.message =~ /#{orm_backend}/
      end
    end
  end
end
