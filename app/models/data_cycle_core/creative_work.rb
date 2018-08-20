# frozen_string_literal: true

module DataCycleCore
  class CreativeWork < Content::DataHash
    extend ActsAsTree::TreeView
    extend ActsAsTree::TreeWalker

    class Translation < Globalize::ActiveRecord::Translation
      include Content::Extensions::ContentTranslation
    end

    class History < Content::Content
      # handle translations with gem Globalize
      translates :headline, :description, :content, :release,
                 :release_id, :release_comment, :history_valid

      content_relations table_name: 'creative_works', postfix: 'history'

      include Content::ContentHistoryLoader
      belongs_to :creative_work

      # callbacks
      before_destroy :destroy_relations, prepend: true

      def destroy_relations
        translations.delete_all
      end
    end
    has_many :histories, -> { order(created_at: :desc) }, class_name: 'DataCycleCore::CreativeWork::History', foreign_key: :creative_work_id

    # handle translations with gem Globalize
    translates :headline, :description, :content, :release,
               :release_id, :release_comment

    # include content specific relations
    content_relations table_name: table_name

    # callbacks
    before_destroy :destroy_relations, prepend: true

    # associations
    belongs_to :primaryImage, class_name: 'Place', primary_key: 'id', foreign_key: 'photo'
    acts_as_tree order: 'position', foreign_key: 'is_part_of'

    include Content::ContentLoader
    include Content::Extensions::CreativeWork

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    private

    def destroy_relations
      translations.delete_all
      content_search_all.delete_all
    end
  end
end
