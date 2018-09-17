# frozen_string_literal: true

module DataCycleCore
  class Organization < Content::DataHash
    include Content::ContentLoader
    include Content::Extensions::Organization

    class Translation < Globalize::ActiveRecord::Translation
      include Content::Extensions::ContentTranslation
    end

    class History < Content::Content
      include Content::ContentHistoryLoader

      translates :headline, :description, :content, :release,
                 :release_id, :release_comment, :history_valid
      content_relations table_name: 'organizations', postfix: 'history'
      belongs_to :organization
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::Organization::History', foreign_key: :organization_id

    translates :headline, :description, :content, :release, :release_id, :release_comment
    content_relations table_name: table_name

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end
  end
end
