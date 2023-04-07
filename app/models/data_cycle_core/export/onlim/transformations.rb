# frozen_string_literal: true

module DataCycleCore
  module Export
    module Onlim
      module Transformations
        def self.t(*args)
          DataCycleCore::Export::Onlim::TransformationFunctions[*args]
        end

        def self.whitelist
          default_attributes =
            ['name', 'description', 'address', 'ds:compliesWith',
             'image', 'sdLicense', 'sdPublisher', 'keywords']
          default_place_attributes = default_attributes + ['geo']
          {
            'Organization' =>
              ['name', 'description', 'address', 'url', 'telephone', 'email', 'ds:compliesWith'],
            'PostalAddress' =>
              ['streetAddress', 'addressLocality', 'postalCode', 'ds:compliesWith'],
            'Person' =>
              ['name', 'url', 'ds:compliesWith'],
            'ImageObject' =>
              ['name', 'caption', 'contentUrl', 'thumbnailUrl', 'url', 'uploadDate',
               'copyrightNotice', 'copyrightYear', 'copyrightHolder', 'author',
               'width', 'height', 'contentSize', 'ds:compliesWith'],
            'TouristAttraction' => # POI
              default_place_attributes +
                ['url', 'telephone', 'faxNumber', 'additionalProperty',
                 'openingHoursSpecification'],
            'FoodEstablishment' => # Gastronomischer Betrieb
              default_place_attributes +
                ['url', 'email', 'telephone', 'faxNumber', 'additionalProperty', 'openingHoursSpecification'],
            'LodgingBusiness' => # Unterkunft
              default_place_attributes +
                ['url', 'telephone', 'faxNumber', 'email', 'additionalProperty',
                 'openingHoursSpecification', 'priceRange', 'availableLanguage',
                 'photo'],
            'odta:Trail' => # Tour
              default_place_attributes +
                ['url', 'odta:wayPoint'], # , 'aggregateRating'
            'Event' =>
              default_attributes +
                ['eventSchedule', 'startDate', 'endDate', 'inLanguage', 'location',
                 'organizer', 'performer', 'potentialAction']
          }
        end

        def self.blacklist
          {}
        end

        def self.to_poi
          t(:add_contact_information, ['telephone', 'faxNumber', 'url'])
          .>> t(:add_keywords)
          .>> t(:add_place_description)
          .>> t(:add_action_as_url)
        end

        def self.to_food_establishment
          t(:add_contact_information, ['telephone', 'email', 'url'])
          .>> t(:add_keywords)
          .>> t(:add_food_establishment_description)
        end

        def self.to_lodging_business
          t(:add_contact_information, ['telephone', 'email', 'faxNumber', 'url'])
          .>> t(:rename_graph_keys, {'dc:translation' => 'availableLanguage'})
          .>> t(:add_keywords)
          .>> t(:add_lodging_business_description)
        end

        def self.to_tour
          t(:add_contact_information, ['url'])
          .>> t(:add_keywords)
          .>> t(:add_tour_description)
        end

        def self.to_event
          t(:transform_duration)
          .>> t(:remove_local_business_as_organizer) # TODO: handle local_business als orgnaizer properly.
          .>> t(:rename_graph_keys, {'dc:translation' => 'inLanguage'})
          .>> t(:add_keywords)
          .>> t(:transform_action)
          .>> t(:add_event_description)
        end

        def self.to_organization
          t(:add_contact_information, ['telephone', 'email', 'url'])
        end

        def self.to_person
          t(:identity)
        end

        def self.to_image
          t(:rename_graph_keys, { 'dc:webUrl' => 'url' })
          .>> t(:transform_content_size)
          .>> t(:transform_copyright_notice) # for now until fixed on DZT side
        end

        def self.to_property_value
          t(:transform_numbers)
        end

        def self.to_onlim
          t(:transform_types)
          .>> default_transformations
        end

        def self.default_transformations
          t(:transform_time, ['opens', 'closes', 'startTime', 'endTime'])
          .>> t(:add_main_content_license)
          .>> t(:remove_namespaced_data)
          .>> t(:context_to_onlim)
          .>> t(:type_to_onlim)
          .>> t(:apply_whitelist, whitelist)
          .>> t(:apply_blacklist, blacklist)
          .>> t(:add_complies_with)
          .>> t(:remove_thing_stubs)
          .>> t(:strip_all)
        end
      end
    end
  end
end
