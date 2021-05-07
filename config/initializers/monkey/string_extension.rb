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

    def underscore_blanks
      underscore.parameterize(separator: '_')
    end

    def transliterate_german
      gsub GERMAN_REGEXP, GERMAN_HASH
    end

    def strip_tags
      ActionController::Base.helpers.strip_tags(self)
    end
  end
end

String.include DataCycleCore::StringExtension
