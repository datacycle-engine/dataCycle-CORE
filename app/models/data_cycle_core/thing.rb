# frozen_string_literal: true

module DataCycleCore
  class Thing < Content::DataHash
    include Content::ContentLoader
    include Content::Extensions::Thing

    class Translation < Globalize::ActiveRecord::Translation
      include Content::Extensions::ContentTranslation
    end

    class History < Content::Content
      include Content::ContentHistoryLoader

      translates :name, :description, :content, :history_valid
      content_relations table_name: 'things', postfix: 'history'
      belongs_to :thing
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Thing::History', foreign_key: :thing_id, inverse_of: :thing

    translates :name, :description, :content
    content_relations table_name: table_name

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end
  end
end
