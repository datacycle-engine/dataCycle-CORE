# frozen_string_literal: true

module DataCycleCore
  class Organization < Content::DataHash
    class Translation < Globalize::ActiveRecord::Translation
      include Content::Extensions::ContentTranslation
    end

    class History < Content::Content
      # handle translations with gem Globalize
      translates :headline, :description, :content, :release,
                 :release_id, :release_comment, :history_valid

      content_relations table_name: 'organizations', postfix: 'history'

      include Content::ContentHistoryLoader
      belongs_to :organization

      # callbacks
      before_destroy :destroy_relations, prepend: true

      def destroy_relations
        translations.delete_all
      end
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Organization::History', foreign_key: :organization_id

    # handle translations with gem Globalize
    translates :headline, :description, :content, :release,
               :release_id, :release_comment

    # include content specific relations
    content_relations table_name: table_name

    # callbacks
    before_destroy :destroy_relations, prepend: true

    include Content::ContentLoader
    include Content::Extensions::Organization

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def destroy_relations
      translations.delete_all
      content_search_all.delete_all
    end
  end
end
