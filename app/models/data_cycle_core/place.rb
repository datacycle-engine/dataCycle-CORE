module DataCycleCore
  class Place < ActiveRecord::Base

    # handle translations with gem Globalize
    translates :name, :description, :addressLocality, :streetAddress,
      :postalCode, :addressCountry, :faxNumber, :telephone, :email,
      :url, :hoursAvailable

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # custom setter
    include DataSetter

    # associations
    belongs_to :external_sources

    has_many :classifications_places
    has_many :classifications, through: :classifications_places
    has_many :classifications_groups, through: :classifications
    has_many :classifications_aliases, through: :classifications_groups

    has_one :primaryImage, class_name: 'CreativeWork', primary_key: 'photo', foreign_key: 'id'
    has_many :creative_works_places
    has_many :creative_works, through: :creative_works_places

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    private

    def destroy_translations
      self.translations.delete_all
    end

  end
end
