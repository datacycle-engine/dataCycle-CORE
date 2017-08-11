module DataCycleCore
  module OutdoorActive
    module PoiAttributeTransformation
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

      def latitude
        self['geometry'].try(:split, /[, ]/, 3).try(:[], 1).try(:to_f)
      end

      def longitude
        self['geometry'].try(:split, /[, ]/, 3).try(:[], 0).try(:to_f)
      end

      def location
        RGeo::Geographic.spherical_factory(srid: 4326).point(longitude, latitude)        
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

      def price
        self['fee'].try(:strip)
      end

      def directions
        self['gettingThere'].try(:strip)
      end

      def parking
        self['parking'].try(:strip)
      end

      def to_h
        Hash[PoiAttributeTransformation.public_instance_methods.reject { |m| 
          m == :to_h 
        }.map { |m| 
          [m, self.send(m)] 
        }].reject { |k, v| v.nil? }
      end
    end
  end
end
