# frozen_string_literal: true

module DataCycleCore
  class Place < Content::DataHash
    class Translation < Globalize::ActiveRecord::Translation
      include Content::Extensions::ContentTranslation
      include Content::Extensions::PlaceTranslation
    end

    class History < Content::Content
      translates :name, :headline, :description, :url, :hours_available, :content,
                 :release, :release_id, :release_comment, :history_valid

      include Content::ContentHistoryLoader
      content_relations table_name: 'places', postfix: 'history'
      belongs_to :place

      before_destroy :destroy_relations, prepend: true
      def destroy_relations
        translations.delete_all
      end
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Place::History', foreign_key: :place_id
    has_one :primaryImage, class_name: 'CreativeWork', primary_key: 'photo', foreign_key: 'id'

    translates :name, :headline, :description, :url, :hours_available, :content,
               :release, :release_id, :release_comment

    content_relations table_name: table_name
    include Content::ContentLoader
    include Content::Extensions::Place

    before_destroy :destroy_relations, prepend: true
    def destroy_relations
      translations.delete_all
      content_search_all.delete_all
    end

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end
  end
end
