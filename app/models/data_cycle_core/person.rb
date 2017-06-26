module DataCycleCore
  class Person < ApplicationRecord

    # handle translations with gem Globalize
    translates :content, :properties

    # callbacks
    before_destroy :destroy_translations, prepend: true

    has_many :creative_work_persons
    has_many :creative_works, through: :creative_work_persons

    # custom setter
    include DataSetter

    attr_accessor :datahash



    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def destroy_translations
      self.translations.destroy_all
    end

  end
end
