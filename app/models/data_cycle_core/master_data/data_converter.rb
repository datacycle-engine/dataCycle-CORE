# frozen_string_literal: true

module DataCycleCore
  module MasterData
    module DataConverter
      # Safe fallback mode used when a field has no explicit ``data-size``.
      # Keeps basic inline formatting (e.g. from importers) while still
      # stripping scripts, event handlers and other dangerous markup.
      DEFAULT_SANITIZATION_MODE = :default

      SANITIZE_TAGS = {
        default: ['b', 'strong', 'i', 'em', 'u', 'br', 'p'],
        none: ['br', 'p'],
        minimal: ['b', 'strong', 'i', 'em', 'u', 'br', 'p'],
        basic: ['b', 'strong', 'i', 'em', 'h1', 'h2', 'h3', 'h4', 'u', 'br', 'p', 'sub', 'sup'],
        full: ['b', 'strong', 'i', 'em', 'h1', 'h2', 'h3', 'h4', 'u', 'blockquote', 'ul', 'ol', 'li', 'br', 'a', 'contentlink', 'p', 'sub', 'sup', 'span']
      }.freeze

      SANITIZED_ATTRIBUTES = {
        default: [],
        none: [],
        minimal: [],
        basic: [],
        full: ['href', 'target', 'rel', 'class', 'data-href', 'data-dc-tooltip', 'data-dc-tooltip-id']
      }.freeze

      # Converts a given value into a specific internal type.
      #
      # @param type [String] Target type identifier
      # @param data [Object] Input value to convert
      # @param definition [Hash, nil] Optional field definition for additional context
      # @return [Object] Converted value
      def self.convert_to_type(type, data, definition = nil)
        case type
        when 'key'
          data
        when 'number'
          string_to_number(data, definition)
        when 'string', 'oembed', 'slug'
          string_to_string(data, get_sanitization_mode(definition))
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

      # Converts a given value into a string representation.
      #
      # @param type [String] Source type identifier
      # @param data [Object] Input value
      # @param definition [Hash, nil] Optional field definition
      # @return [String, nil] String representation of the value
      def self.convert_to_string(type, data, definition = nil)
        case type
        when 'key', 'number'
          data&.to_s
        when 'string', 'oembed', 'slug'
          string_to_string(data, get_sanitization_mode(definition))
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

      # Fixes surrogate pair encoding issues in HTML entities.
      #
      # @param value [String] Input string containing surrogate pairs
      # @return [String] Corrected string
      def self.fix_surrogate_pairs(value)
        value.gsub(/&#(5[56]\d{3});&#(5[67]\d{3});/) do
          high = ::Regexp.last_match(1).to_i
          low = ::Regexp.last_match(2).to_i
          codepoint = 0x10000 + ((high - 0xD800) << 10) + (low - 0xDC00)
          [codepoint].pack('U*')
        end
      end

      # Converts and sanitizes a string value.
      #
      # @param value [String] Input string
      # @param sanitization_mode [String, Symbol, nil] Sanitization mode
      def self.string_to_string(value, sanitization_mode = nil)
        return if value.try(:strip_tags).blank?

        value = value.encode('UTF-8') if value.encoding.name == 'ASCII-8BIT' # ActiveStorage generates ASCII-8BIT encoded URLs
        value = fix_surrogate_pairs(value)

        coder = HTMLEntities.new
        old_value = coder.decode(value)
        old_value = old_value
          &.unicode_normalize(:nfc)
          &.delete("\u0000") # jsonb does not support \u0000 (https://www.postgresql.org/docs/11/datatype-json.html)
          &.safe_squish

        old_value = sanitize_html_string(old_value, sanitization_mode)
        loop do # to get rid of more than one occurrence of the tags
          new_value = old_value
            &.strip
            &.gsub(%r{^(<p>\s*(<br>)*\s*</p>)+|(<p>\s*(<br>)*\s*</p>)+$}, '') # remove empty lines at the start and end of the String
            &.gsub(/^\s*<br>\s*|\s*<br>\s*$/, '') # remove <br> (with whitespace) at the start and end of the String
            &.strip
            &.safe_squish
          break if new_value == old_value

          old_value = new_value
        end
        old_value
      end

      # Converts a string to a numeric value.
      #
      # @param value [String, Numeric, nil] Input value
      # @param definition [Hash] Field definition containing format info
      # @return [Integer, Float, nil] Converted number
      def self.string_to_number(value, definition)
        number_format = definition&.dig('validations', 'format')
        case number_format
        when 'integer'
          value&.to_i
        else
          value&.to_f
        end
      end

      # Converts a geographic object to a string.
      #
      # @param value [Object] Geographic object or string
      # @return [String, nil] String representation
      # @raise [RGeo::Error::ParseError] If input is invalid
      def self.geographic_to_string(value)
        return nil if value.blank?
        return value if value.is_a?(::String) && string_to_geographic(value).methods.include?(:geometry_type)
        raise RGeo::Error::ParseError, 'expected a geographic object of some sorts' unless value.methods.include?(:geometry_type)

        value.to_s
      end

      # Converts a string into a geographic object.
      #
      # @param value [String, Object] Input value
      # @return [Object, nil] Geographic object
      # @raise [RGeo::Error::ParseError] If input is invalid
      def self.string_to_geographic(value)
        return if value.blank?
        return value if value.try(:is_3d?)

        value = value.to_s
        raise RGeo::Error::ParseError, 'expected a string containing geographic data of some sorts' unless value.is_a?(::String)

        factory_options = {
          srid: 4326,
          has_z_coordinate: true,
          uses_lenient_assertions: true,
          wkt_parser: { support_wkt12: true },
          wkt_generator: { convert_case: :upper, tag_format: :wkt12 }
        }

        RGeo::Geographic.spherical_factory(**factory_options).parse_wkt(value)
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

      # Converts a boolean value to string.
      #
      # @param value [String, Boolean, nil] Input value
      # @return [String, nil] String representation
      # @raise [ArgumentError] If invalid input
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

      # Converts a string into a boolean.
      #
      # @param value [String, Boolean, nil] Input value
      # @return [Boolean, nil] Converted boolean
      # @raise [ArgumentError] If conversion fails
      def self.datetime_to_string(value)
        return nil if value.blank?

        if value.is_a?(::String)
          raise ArgumentError, 'expected a datetime of some sorts' unless value.in_time_zone.acts_like?(:time)

          return value.squish
        end
        raise ArgumentError, 'expected a datetime of some sorts' unless value.acts_like?(:time)

        value.to_s
      end

      # Converts a string into a datetime object.
      #
      # @param value [String, Time, nil] Input value
      # @return [Time, nil] Converted datetime
      # @raise [ArgumentError] If conversion fails
      def self.string_to_datetime(value)
        return nil if value.blank?
        return value if value.acts_like?(:time)
        raise ArgumentError, 'can not convert to a datetime' unless value.is_a?(::String)

        value.in_time_zone.presence&.change(usec: 0) || raise(ArgumentError, 'can not convert to a datetime')
      end

      # Converts a string into a datetime object.
      #
      # @param value [String, Time, nil] Input value
      # @return [Time, nil] Converted datetime
      # @raise [ArgumentError] If conversion fails
      def self.date_to_string(value)
        return nil if value.blank?

        if value.is_a?(::String)
          raise ArgumentError, 'expected a date of some sorts' unless value.to_date.acts_like?(:date)

          return value.squish
        end
        raise ArgumentError, 'expected a date of some sorts' unless value.acts_like?(:date)

        value.to_s
      end

      # Converts a string into a date object.
      #
      # @param value [String, Date, nil] Input value
      # @return [Date, nil] Converted date
      # @raise [ArgumentError] If conversion fails
      def self.string_to_date(value)
        return nil if value.blank?
        return value if value.acts_like?(:date)
        raise ArgumentError, 'can not convert to a date' unless value.is_a?(::String)

        value.to_date.presence || raise(ArgumentError, 'can not convert to a date')
      rescue Date::Error => e
        raise ArgumentError, e.message
      end

      # Sanitizes an HTML string based on configured mode.
      #
      # @param value [String] Input HTML string
      # @param sanitization_mode [String, Symbol, nil] Sanitization mode
      # @return [String, nil] Sanitized HTML string
      def self.sanitize_html_string(value, sanitization_mode = nil)
        return if value.blank?
        return value unless DataCycleCore::Feature['StringSanitizer']&.enabled?

        mode = sanitization_mode&.to_sym
        mode = DEFAULT_SANITIZATION_MODE unless SANITIZE_TAGS.key?(mode)
        tags = SANITIZE_TAGS[mode]
        attributes = SANITIZED_ATTRIBUTES[mode] || []

        sanitized_value = ActionController::Base.helpers.sanitize(value, tags:, attributes:)

        # Decode only the ampersand-escaping that ``sanitize`` applies to text,
        # so legitimate content stays readable (URLs with query params like
        # ``?v=x&t=1s``, "Tom & Jerry", etc.). Crucially we do NOT decode
        # ``&lt;``/``&gt;`` here: a blanket ``CGI.unescapeHTML`` used to do that
        # and would re-animate entity-encoded markup that ``sanitize`` had
        # neutralized (stored XSS via double-encoded payloads). A literal ``&``
        # can never start a tag, so this remains safe.
        # ``gsub`` on a SafeBuffer returns a SafeBuffer; return a plain String to
        # preserve this method's contract (serialization type-checks for String).
        String.new(String(sanitized_value).gsub('&amp;', '&'))
      end

      # Truncates HTML content while preserving structure.
      #
      # @param truncate_html [String] HTML input
      # @param limit [Integer] Character limit
      # @param omission [String] Omission string
      # @param ignore_whitespace [Boolean] Whether to ignore whitespace
      # @return [String] Truncated HTML
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

      # Recursively truncates a node while preserving HTML structure.
      #
      # @param node [Nokogiri::XML::Node] Current node
      # @param char_count [Integer] Current character count
      # @param limit [Integer] Maximum character limit
      # @param omission [String] Omission string
      # @param ignore_whitespace [Boolean] Whether to ignore whitespace
      # @return [Array<(Nokogiri::XML::Node, Integer)>] Truncated node and updated count
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

      # Truncates a string ignoring whitespace characters.
      #
      # @param input_string [String] Input string
      # @param limit [Integer] Character limit
      # @param omission [String] Omission string
      # @return [Array<(String, Integer)>] Truncated string and count
      def self.truncate_ignoring_blank_spaces(input_string, limit, omission: '...')
        truncate_string(input_string, 0, limit, omission:, ignore_whitespace: true)
      end

      # Truncates a string based on character limit.
      #
      # @param truncate_string [String] Input string
      # @param count_start [Integer] Initial count
      # @param limit [Integer] Maximum characters
      # @param omission [String] Omission string
      # @param ignore_whitespace [Boolean] Whether to ignore whitespace
      # @return [Array<(String, Integer)>] Truncated string and updated count
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

      # Extracts sanitization mode from a field definition.
      #
      # @param definition [Hash, nil] Field definition
      # @return [String, nil] Sanitization mode
      def self.get_sanitization_mode(definition)
        definition&.dig('ui', 'edit', 'options', 'data-size')
      end
    end
  end
end
