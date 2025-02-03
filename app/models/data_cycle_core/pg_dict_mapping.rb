# frozen_string_literal: true

module DataCycleCore
  class PgDictMapping < ApplicationRecord
    attr_readonly :dict

    has_many :searches, inverse_of: :pg_dict_mapping, dependent: false

    DICT_MAPPINGS = {
      'de'	=> 'german',
      'en'	=> 'english',
      'nl'	=> 'dutch',
      'da'	=> 'danish',
      'fi'	=> 'finnish',
      'fr'	=> 'french',
      'de-CH'	=> 'german',
      'hu'	=> 'hungarian',
      'it'	=> 'italian',
      'no'	=> 'norwegian',
      'pt'	=> 'portuguese',
      'ru'	=> 'russian',
      'es'	=> 'spanish',
      'sv'	=> 'swedish',
      'tr'	=> 'turkish',
      'ar'	=> 'simple',
      'bg'	=> 'simple',
      'cs'	=> 'simple',
      'hr'	=> 'simple',
      'ja'	=> 'simple',
      'ko'	=> 'simple',
      'pl'	=> 'simple',
      'ro'	=> 'simple',
      'sl'	=> 'simple',
      'sk'	=> 'simple',
      'uk'	=> 'simple',
      'nl-BE'	=> 'dutch',
      'zh'	=> 'simple'
    }.freeze

    def self.check_missing
      I18n.available_locales.map(&:to_s) - pluck(:locale)
    end

    def self.upsert_missing
      upsert_all(DICT_MAPPINGS.map { |locale, dict| { locale:, dict: } }, unique_by: :pg_dict_mappings_locale_dict_idx)
    end
  end
end
