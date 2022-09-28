# frozen_string_literal: true

module DataCycleCore
  module Export
    module Onlim
      module Transformations
        def self.t(*args)
          DataCycleCore::Export::Onlim::TransformationFunctions[*args]
        end

        def self.whitelist
          {
            # 'Organization' => ['name', 'url', 'ds:compliesWith'],
            'Person' => ['name', 'url', 'ds:compliesWith'],
            'TouristAttraction' => ['name', 'description', 'address', 'geo', 'ds:compliesWith'], # POI
            'Event' => ['name', 'description', 'address', 'geo', 'ds:compliesWith', 'eventSchedule'],
            'odta:Trail' => ['name', 'description', 'address', 'geo', 'ds:compliesWith'],
            'Gastronomischer Betrieb' => ['name', 'description', 'address', 'geo', 'ds:compliesWith'],
            'LodgingBusiness' => ['name', 'description', 'address', 'geo', 'ds:compliesWith'] # Unterkunft
          }
        end

        def self.blacklist
          {
            'PostalAddress' => ['telephone', 'faxNumber', 'email', 'url']
            # 'POI' =>
            #   ['additionalInformation', 'addressCountry', 'addressLocality', 'attributionUrl',
            #    'author', 'contactName', 'contentScore', 'copyrightNotice', 'dateCreated',
            #    'dateDeleted', 'dateModified', 'directions', 'elevation', 'externalContentScore',
            #    'feratelContentScore', 'hoursAvailable', 'isLinkedTo', 'linkedThing',
            #    'logo', 'openingHoursDescription', 'parking', 'potentialAction', 'price',
            #    'priceRange', 'primaryImage', 'slug', 'subjectOf', 'text', 'useGuidelines']
          }
        end

        def self.default_transformations
          t(:remove_namespaced_data)
          .>> t(:context_to_onlim)
          .>> t(:type_to_onlim)
          .>> t(:add_complies_with)
          .>> t(:remove_thing_stubs)
          .>> t(:apply_whitelist, whitelist)
          .>> t(:apply_blacklist, blacklist)
          .>> t(:strip_all)
        end

        def self.to_poi
          default_transformations
        end

        def self.to_event
          default_transformations
          .>> t(:transform_schedule)
        end
      end
    end
  end
end
