module DataCycleCore
  class Place < Content
    class Translation < Globalize::ActiveRecord::Translation
        include ContentTranslationHelpers
    end

    # handle translations with gem Globalize
    translates :name, :headline, :description, :addressLocality, :streetAddress,
      :postalCode, :addressCountry, :faxNumber, :telephone, :email,
      :url, :hoursAvailable, :address, :content, :properties, :release,
      :release_id, :release_comment

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # custom setter
    include DataSetter

    include Releasable
    include Subscribable
    include ContentHelpers


    attr_accessor :datahash
    # # Arel Helper
    # include ArelHelpers::ArelTable
    # include ArelHelpers::JoinAssociation

    # associations
    belongs_to :external_sources

    has_many :classification_places, dependent: :destroy
    has_many :classifications, through: :classification_places
    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups
    has_many :display_classification_aliases, -> { where("classification_aliases.internal = ?", false) }, through: :classification_groups, source: :classification_alias

    has_one :primaryImage, class_name: 'CreativeWork', primary_key: 'photo', foreign_key: 'id'
    has_many :creative_work_places, dependent: :destroy
    has_many :creative_works, through: :creative_work_places

    has_many :watch_list_data_hashes, as: :hashable, dependent: :destroy
    has_many :watch_lists, through: :watch_list_data_hashes

    has_one :show_link, -> { DataLink.show_links }, class_name: "DataLink", as: :item
    has_one :edit_link, -> { DataLink.edit_links }, class_name: "DataLink", as: :item

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    private

    def destroy_translations
      self.translations.delete_all
    end

  end
end
