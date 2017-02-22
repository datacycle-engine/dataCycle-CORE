module DataCycleCore
  class CreativeWork < ApplicationRecord

    # handle translations with gem Globalize
    translates :content, :properties

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # associations
    belongs_to :primaryImage, class_name: 'Place', primary_key: 'id', foreign_key: 'photo'

    # custom setter
    include DataSetter

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
