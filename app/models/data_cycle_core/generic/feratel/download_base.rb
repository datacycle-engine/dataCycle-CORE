module DataCycleCore
  module Generic
    module Feratel
      module DownloadBase
        def load_location_range_ids(collection, range_codes)
          raise ArgumentError, 'missing collection for loading location ranges' if collection.nil?
          range_codes ||= []

          begin
            Mongoid.override_database("#{@source_type.database_name}_#{external_source.id}")
            DataCycleCore::Generic::Collection.with(collection: collection) do |mongo|
              range_codes.map(&:to_s).uniq.map { |code|
                {
                  code => mongo.where({ 'dump.de._Type' => range_type(code) }).map { |r| r.dump['de']['Id'] }
                }
              }.reduce({}, &:merge)
            end
          ensure
            Mongoid.override_database(nil)
          end
        end

        private

        def range_type(range_code)
          case range_code
          when 'RG' then 'Region'
          when 'DI' then 'District'
          when 'TO' then 'Town'
          end
        end
      end
    end
  end
end
