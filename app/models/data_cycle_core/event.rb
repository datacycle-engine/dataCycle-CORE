module DataCycleCore
  class Event < DataHash

    class Translation < Globalize::ActiveRecord::Translation
        include ContentTranslationHelpers
    end

    class History < DataHash
      # handle translations with gem Globalize
      translates :headline, :description, :content, :properties, :release,
        :release_id, :release_comment, :history_valid

      content_relations table_name: "events", postfix: "history"

      include ContentHelpers
      belongs_to :event

      # callbacks
      before_destroy :destroy_relations, prepend: true

      def destroy_relations
        self.delete_childs(true)
        self.translations.delete_all
      end
    end
    has_many :histories, -> { order(updated_at: :desc) }, class_name: 'DataCycleCore::Event::History', foreign_key: :event_id

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
      self.translations.delete_all
      self.content_search_all.delete_all
    end

  end
end
