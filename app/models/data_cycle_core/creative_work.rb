module DataCycleCore
  class CreativeWork < DataHash

    extend ActsAsTree::TreeView
    extend ActsAsTree::TreeWalker

    class Translation < Globalize::ActiveRecord::Translation
      include ContentTranslationHelpers
    end

    class History < DataHash
      # handle translations with gem Globalize
      translates :headline, :description, :content, :properties, :release,
        :release_id, :release_comment, :history_valid

      content_relations table_name: "creative_works", postfix: "history"

      belongs_to :creative_work
      include ContentHelpers
    end
    has_many :histories, -> { order(updated_at: :desc) }, class_name: 'DataCycleCore::CreativeWork::History', foreign_key: :creative_work_id

    # handle translations with gem Globalize
    translates :headline, :description, :content, :properties, :release,
      :release_id, :release_comment

    # include content specific relations
    content_relations table_name: self.table_name

    # callbacks
    before_destroy :destroy_relations, prepend: true

    # associations
    belongs_to :primaryImage, class_name: 'Place', primary_key: 'id', foreign_key: 'photo'
    acts_as_tree order: 'position', foreign_key: 'is_part_of'

    # custom setter
    include DataSetter

    include ContentHelpers
    include CreativeWorkHelpers

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    private

    def destroy_relations
      self.to_history Time.zone.now
      self.delete_childs true
      self.translations.delete_all
      self.content_search_all.delete_all
    end

  end
end
