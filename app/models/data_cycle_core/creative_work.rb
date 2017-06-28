module DataCycleCore
  class CreativeWork < DataHash
    extend ActsAsTree::TreeView
    extend ActsAsTree::TreeWalker

    # handle translations with gem Globalize
    translates :content, :properties

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # associations
    has_many :classification_creative_works
    has_many :classifications, through: :classification_creative_works
    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups
    has_many :display_classification_aliases, -> { where("classification_aliases.internal = ?", false) }, through: :classification_groups, source: :classification_alias

    belongs_to :primaryImage, class_name: 'Place', primary_key: 'id', foreign_key: 'photo'
    has_many :creative_work_places
    has_many :places, through: :creative_work_places

    has_many :creative_work_persons
    has_many :persons, through: :creative_work_persons

    acts_as_tree order: "position", foreign_key: "isPartOf"

    # custom setter
    include DataSetter

    attr_accessor :datahash


    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def tags
      DataCycleCore::ClassificationAlias.
        joins(classifications: [:creative_works]).
        where("creative_works.id = ?", self.id).
        where("classification_creative_works.tag = ?", true)
    end

    # was replaced by QueryBuilders
    def search(search)
      where("headline LIKE ? OR description LIKE ?", "%#{search}%", "%#{search}%")
    end

    private

    def destroy_translations
      self.translations.destroy_all
    end

  end
end
