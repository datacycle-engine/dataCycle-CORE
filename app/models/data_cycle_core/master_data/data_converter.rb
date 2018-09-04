# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module DataConverter
      def convert_to_type(type, data)
        case type
        when 'key', 'number'
          data
        when 'string'
          DataCycleCore::MasterData::DataConverter.string_to_string(data)
        when 'datetime'
          DataCycleCore::MasterData::DataConverter.string_to_datetime(data)
        when 'boolean'
          DataCycleCore::MasterData::DataConverter.string_to_boolean(data)
        when 'geographic'
          DataCycleCore::MasterData::DataConverter.string_to_geographic(data)
        end
      end

      def convert_to_string(type, data)
        case type
        when 'key', 'number'
          data
        when 'string'
          DataCycleCore::MasterData::DataConverter.string_to_string(data)
        when 'datetime'
          DataCycleCore::MasterData::DataConverter.datetime_to_string(data)
        when 'boolean'
          DataCycleCore::MasterData::DataConverter.boolean_to_string(data)
        when 'geographic'
          DataCycleCore::MasterData::DataConverter.geographic_to_string(data)
        end
      end

      def self.string_to_string(value)
        value&.unicode_normalize(:nfkc)
      end

      def self.geographic_to_string(value)
        return nil if value.blank?
        return value if value.is_a?(::String) && string_to_geographic(value).methods.include?(:geometry_type)
        raise RGeo::Error::ParseError, 'expected a geographic object of some sorts' unless value.methods.include?(:geometry_type)
        value.to_s
      end

      def self.string_to_geographic(value)
        return nil if value.blank?
        return value if value.methods.include?(:geometry_type)
        raise RGeo::Error::ParseError, 'expected a string containing geographic data of some sorts' unless value.is_a?(::String)
        begin
          return RGeo::Geographic.spherical_factory(srid: 4326).parse_wkt(value)
        rescue RGeo::Error::ParseError => e
          e
        end
        begin
          return RGeo::Geographic.spherical_factory(srid: 4326, has_z_coordinate: true).parse_wkt(value)
        rescue RGeo::Error::ParseError => e
          e
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
        return nil if value.blank?
        if value.is_a?(::String)
          raise ArgumentError, 'expected a datetime of some sorts' unless value.in_time_zone.acts_like?(:time)
          return value.squish
        end
        raise ArgumentError, 'expected a datetime of some sorts' unless value.acts_like?(:time)
        value.to_s
      end

      def self.string_to_datetime(value)
        return nil if value.blank?
        return value if value.acts_like?(:time)
        raise ArgumentError, 'can not convert to a datetime' unless value.is_a?(::String)
        value.in_time_zone.presence || raise(ArgumentError, 'can not convert to a datetime')
      end
    end
  end
end
