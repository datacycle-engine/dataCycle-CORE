# frozen_string_literal: true

module DataCycleCore
  class Event < Content::DataHash
    include Content::ContentLoader
    include Content::Extensions::Event

    class Translation < Globalize::ActiveRecord::Translation
      include Content::Extensions::ContentTranslation
      include Content::Extensions::Event
    end

    class History < Content::Content
      include Content::ContentHistoryLoader
      translates :headline, :description, :content, :history_valid
      attribute :headline
      attribute :description
      attribute :content
      attribute :history_valid
      content_relations table_name: 'events', postfix: 'history'
      belongs_to :event
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Event::History', foreign_key: :event_id

    translates :headline, :description, :content
    attribute :headline
    attribute :description
    attribute :content
    content_relations table_name: table_name

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end
  end
end
