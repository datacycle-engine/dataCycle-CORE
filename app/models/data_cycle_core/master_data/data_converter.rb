# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module DataConverter
      SANITIZE_TAGS = {
        none: ['br', 'p'],
        minimal: ['b', 'strong', 'i', 'em', 'u', 'br', 'p'],
        basic: ['b', 'strong', 'i', 'em', 'h1', 'h2', 'h3', 'h4', 'u', 'br', 'p', 'sub', 'sup'],
        full: ['b', 'strong', 'i', 'em', 'h1', 'h2', 'h3', 'h4', 'u', 'blockquote', 'ul', 'ol', 'li', 'br', 'a', 'contentlink', 'p', 'sub', 'sup', 'span']
      }.freeze

      SANITIZED_ATTRIBUTES = {
        none: [],
        minimal: [],
        basic: [],
        full: ['href', 'target', 'rel', 'class', 'data-href', 'data-dc-tooltip', 'data-dc-tooltip-id']
      }.freeze

      def self.convert_to_type(type, data, definition = nil)
        case type
        when 'key'
          data
        when 'number'
          string_to_number(data, definition)
        when 'string', 'oembed', 'slug'
          string_to_string(data, definition)
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

      def self.convert_to_string(type, data, definition = nil)
        case type
        when 'key', 'number'
          data&.to_s
        when 'string', 'oembed', 'slug'
          string_to_string(data, definition)
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

      def self.string_to_string(value, definition = nil)
        return if value.try(:strip_tags).blank?
        value = value.encode('UTF-8') if value.encoding.name == 'ASCII-8BIT' # ActiveStorage generates ASCII-8BIT encoded URLs
        old_value = value
          &.unicode_normalize(:nfc)
          &.delete("\u0000") # jsonb does not support \u0000 (https://www.postgresql.org/docs/11/datatype-json.html)
          &.squish

        old_value = sanitize_html_string(old_value, definition)
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
        return value if value.try(:is_3d?)
        value = value.to_s
        raise RGeo::Error::ParseError, 'expected a string containing geographic data of some sorts' unless value.is_a?(::String)

        factory_options = {
          uses_lenient_assertions: true,
          srid: 4326,
          wkt_parser: { support_wkt12: true },
          wkt_generator: { convert_case: :upper, tag_format: :wkt12 },
          has_z_coordinate: true
        }

        RGeo::Geographic.simple_mercator_factory(**factory_options).parse_wkt(value)
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

      def self.sanitize_html_string(value, definition = nil)
        return value unless DataCycleCore::Feature['StringSanitizer']&.enabled?

        data_size = definition&.dig('ui', 'edit', 'options', 'data-size')
        tags = SANITIZE_TAGS[data_size&.to_sym] || []
        attributes = SANITIZED_ATTRIBUTES[data_size&.to_sym] || []
        ActionController::Base.helpers.sanitize(value, tags:, attributes:)
      end

      def self.truncate_html_preserving_structure(truncate_html, limit, omission: '...', ignore_whitespace: true)
        doc = Nokogiri::HTML::DocumentFragment.parse(truncate_html)
        truncated = Nokogiri::HTML::DocumentFragment.parse('')

        char_count = 0
        doc.children.each do |node|
          break if char_count >= limit
          node, char_count = truncate_node(node, char_count, limit, omission:, ignore_whitespace:)
          truncated.add_child(node)
        end

        truncated.to_html.strip
      end

      def self.truncate_node(node, char_count, limit, omission: '...', ignore_whitespace: true)
        return '', char_count if char_count >= limit
        if node.text?
          text = node.text
          truncated_text, char_count = truncate_string(text, char_count, limit, omission:, ignore_whitespace:)
          return Nokogiri::XML::Text.new(truncated_text, node.document), char_count

        elsif node.element?
          new_node = Nokogiri::XML::Node.new(node.name, node.document)
          node.attributes.each { |name, attr| new_node[name] = attr.value }

          node.children.each do |child|
            break if char_count >= limit
            new_child, char_count = truncate_node(child, char_count, limit, omission:, ignore_whitespace:)
            new_node.add_child(new_child) if new_child
          end

          return new_node, char_count
        end
      end

      def self.truncate_ignoring_blank_spaces(input_string, limit, omission: '...')
        truncate_string(input_string, 0, limit, omission:, ignore_whitespace: true)
      end

      def self.truncate_string(truncate_string, count_start, limit, omission: '...', ignore_whitespace: true)
        count = count_start
        result = +''

        truncate_string.each_char do |char|
          if !ignore_whitespace || char =~ /\S/
            break if count >= limit
            count += 1
          end
          result << char
        end

        if count >= limit
          result.strip!
          result += omission
        end
        return result, count
      end
    end
  end
end
