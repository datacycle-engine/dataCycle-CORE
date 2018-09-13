# frozen_string_literal: true

module DataCycleCore
  class Place < Content::DataHash
    include Content::ContentLoader
    include Content::Extensions::Place

    class Translation < Globalize::ActiveRecord::Translation
      include Content::Extensions::ContentTranslation
      include Content::Extensions::PlaceTranslation
    end

    class History < Content::Content
      include Content::ContentHistoryLoader

      translates :name, :headline, :description, :url, :hours_available, :content,
                 :release, :release_id, :release_comment, :history_valid
      content_relations table_name: 'places', postfix: 'history'
      belongs_to :place
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Place::History', foreign_key: :place_id

    translates :name, :headline, :description, :url, :hours_available, :content, :release, :release_id, :release_comment
    content_relations table_name: table_name

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end
  end
end
