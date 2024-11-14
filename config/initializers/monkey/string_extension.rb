# frozen_string_literal: true

module DataCycleCore
  module StringExtension
    GERMAN_HASH = { 'Ä' => 'Ae', 'ä' => 'ae',
                    'Ö' => 'Oe', 'ö' => 'oe', 'Ü' => 'Ue',
                    'ü' => 'ue', 'ß' => 'ss' }.freeze
    GERMAN_REGEXP = /[ÄäÖöÜüß]/
    ENCODING_GUESSES = [
      Encoding::ISO_8859_1
    ].freeze

    UUID_REGEX = /^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/i

    def attribute_name_from_key
      self[/\[?([^\[\]]+)\]?$/, 1]
    end

    def replace_attribute_name_in_key(new_attribute_name)
      gsub(/(\[?)([^\[\]]+)(\]?)$/, "\\1#{new_attribute_name}\\3")
    end

    def attribute_path_from_key
      split(/[\[\]]+/).flatten.except(['thing', 'datahash', 'translations', *I18n.available_locales.map(&:to_s)]).grep_v(/^\d+$/)
    end

    def underscore_blanks
      underscore.parameterize(separator: '_')
    end

    def transliterate_german
      gsub GERMAN_REGEXP, GERMAN_HASH
    end

    def to_slug
      parameterize(separator: '-')
    end

    def uuid?
      UUID_REGEX.match?(self)
    end

    def strip_tags
      ActionController::Base.helpers.strip_tags(self)
    rescue StandardError
      self
    end

    def encode_utf8!
      return self if is_utf8?

      ENCODING_GUESSES.each do |guess|
        force_encoding(guess)
        return encode!(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: '') if valid_encoding?
      end

      raise Encoding::UndefinedConversionError 'could not guess encoding!'
    end
  end
end

String.include DataCycleCore::StringExtension
