module DataCycleCore
  class Event < DataHash

    class Translation < Globalize::ActiveRecord::Translation
        include ContentTranslationHelpers
    end




    class History < DataHash
      # handle translations with gem Globalize
      translates :event_id, :headline, :description, :content, :properties, :release,
        :release_id, :release_comment, :history_valid

      belongs_to :event
    end

    has_many :history, class_name: 'DataCycleCore::Event::History', foreign_key: :event_id




    # handle translations with gem Globalize
    translates :headline, :description, :content, :properties, :release,
      :release_id, :release_comment

    # include content specific relations
    content_relations table_name: self.table_name

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # custom setter
    include DataSetter

    include ContentHelpers

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def destroy_translations
      self.translations.destroy_all
    end

  end
end
