# frozen_string_literal: true

module DataCycleCore
  module Export
    module Onlim
      module Transformations
        def self.t(*args)
          DataCycleCore::Export::Onlim::TransformationFunctions[*args]
        end

        def self.whitelist
          default_attributes = ['name', 'description', 'address', 'ds:compliesWith', 'image', 'sdLicense', 'sdPublisher']
          default_place_attributes = default_attributes + ['geo']
          {
            'Organization' =>
              ['name', 'url', 'address', 'ds:compliesWith'],
            'PostalAddress' =>
              ['streetAddress', 'addressLocality', 'postalCode', 'ds:compliesWith'],
            'Person' =>
              ['name', 'url', 'ds:compliesWith'],
            'ImageObject' =>
              ['name', 'contentUrl', 'thumbnailUrl', 'width', 'height', 'fileFormat', 'uploadDate', 'copyrightNotice', 'copyrightYear', 'copyrightHolder', 'ds:compliesWith'],
            'TouristAttraction' => default_place_attributes, # POI
            'LodgingBusiness' => default_place_attributes, # Unterkunft
            'odta:Trail' => default_place_attributes, # Tour
            'Event' => default_attributes + ['eventSchedule'],
            'FoodEstablishment' => default_place_attributes # Gastronomischer Betrieb
          }
        end

        def self.blacklist
          {
            # 'PostalAddress' => ['telephone', 'faxNumber', 'email', 'url']
          }
        end

        def self.default_transformations(existing_ids = [])
          t(:add_main_content_license)
          .>> t(:remove_namespaced_data)
          .>> t(:context_to_onlim)
          .>> t(:type_to_onlim)
          .>> t(:apply_whitelist, whitelist)
          .>> t(:apply_blacklist, blacklist)
          .>> t(:add_complies_with)
          .>> t(:remove_thing_stubs)
          .>> t(:remove_existing_object_data, existing_ids)
          .>> t(:strip_all)
        end

        def self.to_poi(existing_ids)
          default_transformations(existing_ids)
        end

        def self.to_event(existing_ids)
          default_transformations(existing_ids)
          .>> t(:transform_schedule)
        end
      end
    end
  end
end
