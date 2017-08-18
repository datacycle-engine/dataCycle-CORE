module DataCycleCore
  module OutdoorActive
    module TourAttributeTransformation
      def name
        self['title'].try(:strip)
      end

      def description
        self['shortText'].try(:strip)
      end

      def text
        self['longText'].try(:strip)
      end

      def elevation
        self['altitude'].try(:to_f)
      end

      def start_location
        longitude = self['startingPoint'].try(:[], 'lon')
        latitude = self['startingPoint'].try(:[], 'lat')

        if longitude && latitude
          RGeo::Geographic.spherical_factory(srid: 4326).point(longitude, latitude)        
        else
          nil
        end
      end

      def tour
        factory = RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true)

        factory.line_string(
            self['geometry'].try(:split, ' ')
            .try(:map) { |p| p.split(',').map(&:to_f) }
            .try(:map) { |p| factory.point(*p) }
          )
      end

      def ascent
        self['elevation'].try(:[], 'ascent')
      end

      def descent
        self['elevation'].try(:[], 'descent')
      end

      def min_altitude
        self['elevation'].try(:[], 'minAltitude')
      end

      def max_altitude
        self['elevation'].try(:[], 'maxAltitude')
      end

      def length
        self['length'].try(:to_f)
      end

      def duration
        self['time'].try(:[], 'min').try(:to_i)
      end

      def condition_rating    
        self['rationg'].try(:[], 'condition').try(:to_i)
      end

      def difficulty_rating
        self['rationg'].try(:[], 'difficulty').try(:to_i)
      end

      def experience_rating
        self['rationg'].try(:[], 'experience').try(:to_i)
      end

      def landscape_rating
        self['rationg'].try(:[], 'landscape').try(:to_i)
      end

      def address_locality
        self['address'].try(:[], 'town').try(:strip)
      end

      def street_address
        unless self['address'].try(:[], 'street').try(:strip).blank?
          [
            self['address'].try(:[], 'street').try(:strip),
            self['address'].try(:[], 'housenumber').try(:strip)            
          ].join(' ')
        end
      end

      def postal_code
        self['address'].try(:[], 'zipcode').try(:strip)
      end

      def address_country
        self['countryCode'].try(:strip)
      end

      def fax_number
        self['fax'].try(:strip)
      end

      def telephone
        self['phone'].try(:strip)
      end

      def email
        self['email'].try(:strip)
      end

      def url
        self['homepage'].try(:strip)
      end

      def hours_available
        self['businessHours'].try(:strip)
      end

      def source
        self['meta'].try(:[], 'source').try(:[], 'name').try(:strip)
      end

      def author
        self['meta'].try(:[], 'author').try(:strip)
      end

      def directions
        self['gettingThere'].try(:strip)
      end

      def directions_public_transport
        self['publicTransit'].try(:strip)
      end

      def parking
        self['parking'].try(:strip)
      end

      def instructions
        self['directions'].try(:strip)
      end

      def safety_instructions
        self['safetyGuidelines'].try(:strip)
      end

      def equipment
        self['equipment'].try(:strip)
      end

      def suggestion
        self['tip'].try(:strip)
      end

      def additional_information
        self['additionalInformation'].try(:strip)
      end

      def to_h
        Hash[TourAttributeTransformation.public_instance_methods.reject { |m| 
          m == :to_h 
        }.map { |m| 
          [m, self.send(m)] 
        }].reject { |k, v| v.nil? }
      end
    end
  end
end
