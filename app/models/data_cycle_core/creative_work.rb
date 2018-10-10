# frozen_string_literal: true

module DataCycleCore
  class CreativeWork < Content::DataHash
    extend ActsAsTree::TreeView
    extend ActsAsTree::TreeWalker
    include Content::ContentLoader
    include Content::Extensions::CreativeWork

    class Translation < Globalize::ActiveRecord::Translation
      include Content::Extensions::ContentTranslation
    end

    class History < Content::Content
      include Content::ContentHistoryLoader
      translates :headline, :description, :content, :history_valid
      attribute :headline
      attribute :description
      attribute :content
      attribute :history_valid
      content_relations table_name: 'creative_works', postfix: 'history'
      belongs_to :creative_work
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::CreativeWork::History', foreign_key: :creative_work_id
    acts_as_tree order: 'position', foreign_key: 'is_part_of'

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
