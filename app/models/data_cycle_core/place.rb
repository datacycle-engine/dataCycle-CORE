module DataCycleCore
  class Place < DataHash

    class Translation < Globalize::ActiveRecord::Translation
        include ContentTranslationHelpers
        include PlaceTranslationHelpers
      end

    class History < DataHash
      # handle translations with gem Globalize
      translates :name, :headline, :description, :url, :hours_available, :content,
        :properties, :release, :release_id, :release_comment, :history_valid

      content_relations table_name: "places", postfix: "history"

      include ContentHelpers
      belongs_to :place

      # callbacks
      before_destroy :destroy_relations, prepend: true

      def destroy_relations
        self.translations.delete_all
      end
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Place::History', foreign_key: :place_id

    # handle translations with gem Globalize
    translates :name, :headline, :description, :url, :hours_available, :content,
      :properties, :release, :release_id, :release_comment

    # include content specific relations
    content_relations table_name: self.table_name

    # callbacks
    before_destroy :destroy_relations, prepend: true

    include ContentHelpers
    include PlaceHelpers

    # associations
    has_one :primaryImage, class_name: 'CreativeWork', primary_key: 'photo', foreign_key: 'id'

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    private

    def destroy_relations
      self.translations.delete_all
      self.content_search_all.delete_all
    end

  end
end
