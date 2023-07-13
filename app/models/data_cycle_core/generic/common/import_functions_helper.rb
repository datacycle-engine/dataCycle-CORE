# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Common
      module ImportFunctionsHelper
        def init_mongo_db(utility_object)
          Mongoid.override_database("#{utility_object.source_type.database_name}_#{utility_object.external_source.id}")
          yield
        ensure
          Mongoid.override_database(nil)
        end

        def each_locale(locales)
          locales.each do |locale|
            yield(locale.to_sym)
          end
        end

        def init_logging(utility_object)
          logging = utility_object.init_logging(:import)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end
      end
    end
  end
end
