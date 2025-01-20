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

        def filter_object?(iterator)
          return true if iterator.blank?

          iterator.parameters.size >= 1 && iterator.parameters.any? { |k| k[0].in?([:key, :keyreq]) && k[1] == :filter_object }
        end

        def filtered_items(iterator, locale, filter_object)
          if filter_object?(iterator)
            iterator.call(filter_object:)
          else
            iterator.call(filter_object.mongo_item, locale, filter_object.legacy_source_filter)
          end
        end
      end
    end
  end
end
