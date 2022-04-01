# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GeoImport
      module Transformations
        def self.t(*args)
          DataCycleCore::Generic::Common::Functions[*args]
        end

        def self.to_tour
          t(:stringify_keys)
          .>> t(:rename_keys, 'sde_id' => 'external_key', 'PEVENT_BEZ' => 'name')
          .>> t(:map_value, 'tour', ->(s) { load_geo(s) })
          .>> t(:strip_all)
        end

        def self.load_geo(data_string)
          factory = RGeo::Geographic.simple_mercator_factory
          factory.parse_wkt(data_string)
        end
      end
    end
  end
end
