# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module DataConverter
      def self.convert_to_type(type, data, definition = nil)
        case type
        when 'key'
          data
        when 'number'
          string_to_number(data, definition)
        when 'string', 'oembed', 'slug'
          string_to_string(data)
        when 'date'
          string_to_date(data)
        when 'datetime'
          string_to_datetime(data)
        when 'boolean'
          string_to_boolean(data)
        when 'geographic'
          string_to_geographic(data)
        when 'table'
          data&.map { |v| v&.map(&:to_s) }
        end
      end

      def self.convert_to_string(type, data)
        case type
        when 'key', 'number'
          data&.to_s
        when 'string', 'oembed', 'slug'
          string_to_string(data)
        when 'date'
          date_to_string(data)
        when 'datetime'
          datetime_to_string(data)
        when 'boolean'
          boolean_to_string(data)
        when 'geographic'
          geographic_to_string(data)
        when 'table'
          data&.map { |v| v&.map(&:to_s) }
        end
      end

      def self.string_to_string(value)
        return if value.try(:strip_tags).blank?
        value = value.encode('UTF-8') if value.encoding.name == 'ASCII-8BIT' # ActiveStorage generates ASCII-8BIT encoded URLs
        old_value = value
          &.unicode_normalize(:nfc)
          &.delete("\u0000") # jsonb does not support \u0000 (https://www.postgresql.org/docs/11/datatype-json.html)
          &.squish

        loop do # to get rid of more than one occurrence of the tags
          new_value = old_value
            &.strip
            &.gsub(%r{^(<p>\s*(<br>|&nbsp;)*\s*</p>)+|(<p>\s*(<br>|&nbsp;)*\s*</p>)+$}, '') # remove empty lines at the start and end of the String
            &.gsub(/(\s*&nbsp;\s*)+/, '&nbsp;') # normalize multiple &nbsp; to a single one
            &.gsub(/^\s*<br>\s*|\s*<br>\s*$/, '') # remove <br> (with whitespace) at the start and end of the String
            &.gsub(/^&nbsp;|&nbsp;$/, '') # remove &nbsp; at the start and end of the String
            &.strip
            &.squish
          break if new_value == old_value
          old_value = new_value
        end
        old_value
      end

      def self.string_to_number(value, definition)
        number_format = definition&.dig('validations', 'format')
        case number_format
        when 'integer'
          value&.to_i
        else
          value&.to_f
        end
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

        factory_options = {
          uses_lenient_assertions: true,
          srid: 4326,
          wkt_parser: { support_wkt12: true },
          wkt_generator: { convert_case: :upper, tag_format: :wkt12 }
        }

        begin
          RGeo::Geographic.simple_mercator_factory(**factory_options).parse_wkt(value)
        rescue RGeo::Error::ParseError
          return if factory_options[:has_z_coordinate]

          # if the string contains a Z coordinate, we need to retry with a factory that supports it
          factory_options[:has_z_coordinate] = true
          retry
        rescue StandardError
          nil
        end
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
        value.in_time_zone.presence&.change(usec: 0) || raise(ArgumentError, 'can not convert to a datetime')
      end

      def self.date_to_string(value)
        return nil if value.blank?
        if value.is_a?(::String)
          raise ArgumentError, 'expected a date of some sorts' unless value.to_date.acts_like?(:date)
          return value.squish
        end
        raise ArgumentError, 'expected a date of some sorts' unless value.acts_like?(:date)
        value.to_s
      end

      def self.string_to_date(value)
        return nil if value.blank?
        return value if value.acts_like?(:date)
        raise ArgumentError, 'can not convert to a date' unless value.is_a?(::String)
        value.to_date.presence || raise(ArgumentError, 'can not convert to a date')
      end
    end
  end
end
