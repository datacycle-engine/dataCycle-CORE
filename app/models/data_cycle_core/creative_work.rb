module DataCycleCore
  class CreativeWork < DataHash

    extend ActsAsTree::TreeView
    extend ActsAsTree::TreeWalker

    class Translation < Globalize::ActiveRecord::Translation
      include ContentTranslationHelpers
    end

    # handle translations with gem Globalize
    translates :headline, :description, :content, :properties, :release,
      :release_id, :release_comment

    # include content specific relations
    setup_content_relations table_name: self.table_name

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # associations
    belongs_to :primaryImage, class_name: 'Place', primary_key: 'id', foreign_key: 'photo'
    acts_as_tree order: "position", foreign_key: "isPartOf"

    # custom setter
    include DataSetter

    include Releasable
    include Subscribable
    include ContentHelpers
    include CreativeWorkHelpers

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    private

    def destroy_translations
      self.translations.destroy_all
    end

  end
end
