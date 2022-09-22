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
            'Organisation' => ['name', 'url'],
            'Person' => ['name', 'url'],
            'POI' => ['name', 'description', 'address', 'geo', 'ds:compliesWith'],
            'Event' => ['name', 'description', 'address', 'geo', 'ds:compliesWith'],
            'Tour' => ['name', 'description', 'address', 'ds:compliesWith'],
            'Gastronomischer Betrieb' => ['name', 'description', 'address', 'geo', 'ds:compliesWith'],
            'Unterkunft' => ['name', 'description', 'address', 'geo', 'ds:compliesWith']
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

        def self.to_poi
          t(:context_to_onlim)
          .>> t(:remove_namespaced_data)
          .>> t(:remove_thing_stubs)
          .>> t(:type_to_onlim)
          .>> t(:apply_whitelist, whitelist)
          .>> t(:apply_blacklist, blacklist)
          .>> t(:strip_all)
        end
      end
    end
  end
end
