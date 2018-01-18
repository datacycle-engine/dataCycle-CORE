module DataCycleCore
  class Event < DataHash
    class Translation < Globalize::ActiveRecord::Translation
      include ContentTranslationHelpers
      include EventHelpers
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
        translations.delete_all
      end
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Event::History', foreign_key: :event_id

    # handle translations with gem Globalize
    translates :headline, :description, :content, :properties, :release,
               :release_id, :release_comment

    # include content specific relations
    content_relations table_name: table_name

    # callbacks
    before_destroy :destroy_translations, prepend: true

    include ContentHelpers
    include EventHelpers

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def destroy_translations
      translations.delete_all
      content_search_all.delete_all
    end
  end
end
