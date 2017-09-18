module DataCycleCore
  class Person < DataHash

    class Translation < Globalize::ActiveRecord::Translation
        include ContentTranslationHelpers
    end




    class History < DataHash
      # handle translations with gem Globalize
      translates :headline, :description, :content, :properties, :release,
        :release_id, :release_comment, :history_valid

      content_relations table_name: "persons", postfix: "history"

      belongs_to :person
    end

    has_many :histories, -> { order(updated_at: :desc) }, class_name: 'DataCycleCore::Person::History', foreign_key: :person_id




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
    include PersonHelpers

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def destroy_translations
      self.translations.destroy_all
    end

  end
end
