# frozen_string_literal: true

module DataCycleCore
  class Person < Content::DataHash
    include Content::ContentLoader
    include Content::Extensions::Person

    class Translation < Globalize::ActiveRecord::Translation
    end

    class History < Content::Content
      include Content::ContentHistoryLoader

      translates :headline, :description, :content, :history_valid
      attribute :headline
      attribute :description
      attribute :content
      attribute :history_valid
      content_relations table_name: 'persons', postfix: 'history'
      belongs_to :person
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Person::History', foreign_key: :person_id

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
