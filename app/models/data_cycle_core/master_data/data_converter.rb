module DataCycleCore
  module MasterData
    module DataConverter
      def self.geographic_to_string(value)
        return nil if value.nil?
        return value if value.is_a?(::String) && string_to_geographic(value).methods.include?(:geometry_type)
        if value.methods.include?(:geometry_type)
          value.to_s
        else
          raise RGeo::Error::ParseError, 'expected a geographic object of some sorts'
        end
      end

      def self.string_to_geographic(value)
        return nil if value.blank?
        return value if value.methods.include?(:geometry_type)
        raise RGeo::Error::ParseError, 'expected a string containing geographic data of some sorts' unless value.is_a?(::String)
        exception = nil
        begin
          return RGeo::Geographic.spherical_factory(srid: 4326).parse_wkt(value)
        rescue RGeo::Error::ParseError => e
          exception = e
        end
        begin
          return RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true).parse_wkt(value)
        rescue RGeo::Error::ParseError
          exception = e
        end
        raise e
      end

      def self.boolean_to_string(value)
        return nil if value.nil?
        raise ArgumentError, 'expected a boolean of some sorts' unless value.is_a?(::String) || value.is_a?(::TrueClass) || value.is_a?(::FalseClass)
        returned = nil
        if value.is_a?(::String)
          returned = value.squish
          raise ArgumentError, 'expected a boolean of some sorts' unless ['true', 'false'].include?(returned)
        end
        (returned || value).to_s
      end

      def self.string_to_boolean(value)
        return value if value.is_a?(::TrueClass) || value.is_a?(::FalseClass)
        return nil if value.blank?
        raise ArgumentError, 'can not convert to a boolean' unless value.is_a?(::String)
        case value.squish
        when 'true' then true
        when 'false' then false
        else
          raise ArgumentError, 'can not convert to a boolean'
        end
      end

      def self.datetime_to_string(value)
        return nil if value.nil?
        if value.is_a?(::String)
          if value.in_time_zone.acts_like?(:time)
            return value.squish
          else
            raise ArgumentError, 'expected a datetime of some sorts'
          end
        end
        if value.acts_like?(:time)
          value.to_s
        else
          raise ArgumentError, 'expected a datetime of some sorts'
        end
      end

      def self.string_to_datetime(value)
        return nil if value.nil?
        return value if value.acts_like?(:time)
        raise ArgumentError, 'can not convert to a datetime' unless value.is_a?(::String)
        value.in_time_zone.presence || raise(ArgumentError, 'can not convert to a datetime')
      end
    end
  end
end
