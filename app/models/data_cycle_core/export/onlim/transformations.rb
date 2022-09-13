# frozen_string_literal: true

module DataCycleCore
  module Export
    module Onlim
      module Transformations
        def self.t(*args)
          DataCycleCore::Export::Onlim::TransformationFunctions[*args]
        end

        # + starts_with('@')
        def self.whitelist
          {
            'Organisation' => ['name', 'url'],
            'Person' => ['name', 'url']
          }
        end

        def self.blacklist
          {
            'PostalAddress' => ['telephone', 'faxNumber', 'email', 'url'],
            'POI' =>
              ['additionalInformation', 'addressCountry', 'addressLocality', 'attributionUrl',
               'author', 'contactName', 'contentScore', 'copyrightNotice', 'dateCreated',
               'dateDeleted', 'dateModified', 'directions', 'elevation', 'externalContentScore',
               'feratelContentScore', 'hoursAvailable', 'isLinkedTo', 'linkedThing',
               'logo', 'openingHoursDescription', 'parking', 'potentialAction', 'price',
               'priceRange', 'primaryImage', 'slug', 'subjectOf', 'text', 'useGuidelines']
          }
        end

        def self.to_poi
          t(:context_to_onlim)
          .>> t(:remove_namespaced_data)
          .>> t(:remove_thing_stubs)
          .>> t(:type_to_onlim)
          # .>> t(:apply_full_whitelist, whitelist)
          .>> t(:apply_full_blacklist, blacklist)
          .>> t(:strip_all)
        end
      end
    end
  end
end
