# frozen_string_literal: true

module DataCycleCore
  module StringExtension
    GERMAN_HASH = { 'Ä' => 'Ae', 'ä' => 'ae',
                    'Ö' => 'Oe', 'ö' => 'oe', 'Ü' => 'Ue',
                    'ü' => 'ue', 'ß' => 'ss' }.freeze
    GERMAN_REGEXP = /[ÄäÖöÜüß]/.freeze

    def attribute_name_from_key
      split(/[\[\]]+/).last&.underscore
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
      I18n.transliterate(self).parameterize(preserve_case: false, separator: '-')
    end

    def uuid?
      uuid = /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/
      length == 36 && !(downcase =~ uuid).nil?
    end

    def strip_tags
      ActionController::Base.helpers.strip_tags(self)
    end
  end
end

String.include DataCycleCore::StringExtension
