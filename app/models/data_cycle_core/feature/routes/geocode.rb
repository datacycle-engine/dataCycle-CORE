# frozen_string_literal: true

module DataCycleCore
  module Feature
    module Routes
      module Geocode
        def self.extend(router)
          router.instance_exec do
            get '/things/geocode_address', action: :geocode_address, controller: 'things', as: 'geocode_address_thing'
            get '/things/reverse_geocode_address', action: :reverse_geocode_address, controller: 'things', as: 'reverse_geocode_address_thing'
          end
        end
      end
    end
  end
end
