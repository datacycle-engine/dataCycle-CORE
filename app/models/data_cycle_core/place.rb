module DataCycleCore
  class Place < DataHash

    class Translation < Globalize::ActiveRecord::Translation
        include ContentTranslationHelpers
    end

    # handle translations with gem Globalize
    translates :name, :headline, :description, :addressLocality, :streetAddress,
      :postalCode, :addressCountry, :faxNumber, :telephone, :email,
      :url, :hoursAvailable, :content, :properties, :release,
      :release_id, :release_comment

    # include content specific relations
    setup_content_relations table_name: self.table_name

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # custom setter
    include DataSetter

    include Releasable
    include ContentHelpers
    include PlaceHelpers

    # associations
    has_one :primaryImage, class_name: 'CreativeWork', primary_key: 'photo', foreign_key: 'id'

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
