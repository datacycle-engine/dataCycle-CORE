module DataCycleCore
  class Place < DataHash

    # handle translations with gem Globalize
    translates :name, :addressLocality, :streetAddress,
      :postalCode, :addressCountry, :faxNumber, :telephone, :email,
      :url, :hoursAvailable, :address, :content, :properties

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # custom setter
    include DataSetter
    # # Arel Helper
    # include ArelHelpers::ArelTable
    # include ArelHelpers::JoinAssociation

    # associations
    belongs_to :external_sources

    has_many :classification_places
    has_many :classifications, through: :classification_places
    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups

    has_one :primaryImage, class_name: 'CreativeWork', primary_key: 'photo', foreign_key: 'id'
    has_many :creative_work_places
    has_many :creative_works, through: :creative_work_places

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
