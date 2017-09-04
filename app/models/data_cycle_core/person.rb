module DataCycleCore
  class Person < DataHash
    class Translation < Globalize::ActiveRecord::Translation
        include ContentTranslationHelpers
    end

    # handle translations with gem Globalize
    translates :headline, :description, :content, :properties

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # associations
    belongs_to :external_source

    has_many :creative_work_persons, dependent: :destroy
    has_many :creative_works, through: :creative_work_persons

    has_many :event_persons, dependent: :destroy
    has_many :events, through: :event_persons

    has_many :person_places, dependent: :destroy
    has_many :places, through: :person_places

    has_many :classification_persons
    has_many :classifications, through: :classification_persons

    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups
    has_many :display_classification_aliases, -> { where("classification_aliases.internal = ?", false) }, through: :classification_groups, source: :classification_alias

    has_many :watch_list_data_hashes, as: :hashable, dependent: :destroy
    has_many :watch_lists, through: :watch_list_data_hashes

    has_one :show_link, -> { DataLink.show_links }, class_name: "DataLink", as: :item
    has_one :edit_link, -> { DataLink.edit_links }, class_name: "DataLink", as: :item

    # custom setter
    include DataSetter

    include Subscribable
    include ContentHelpers
    include PersonHelpers


    attr_accessor :datahash



    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def destroy_translations
      self.translations.destroy_all
    end

  end
end
