# frozen_string_literal: true

module DataCycleCore
  class Person < Content::DataHash
    class Translation < Globalize::ActiveRecord::Translation
      include Content::Extensions::ContentTranslation
    end

    class History < Content::Content
      translates :headline, :description, :content, :release,
                 :release_id, :release_comment, :history_valid

      include Content::ContentHistoryLoader
      content_relations table_name: 'persons', postfix: 'history'
      belongs_to :person

      before_destroy :destroy_relations, prepend: true
      def destroy_relations
        translations.delete_all
      end
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Person::History', foreign_key: :person_id

    translates :headline, :description, :content, :release,
               :release_id, :release_comment

    content_relations table_name: table_name
    include Content::ContentLoader
    include Content::Extensions::Person

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
