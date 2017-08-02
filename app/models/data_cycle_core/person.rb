module DataCycleCore
  class Person < DataHash

    # handle translations with gem Globalize
    translates :content, :properties

    # callbacks
    before_destroy :destroy_translations, prepend: true

    has_many :creative_work_persons
    has_many :creative_works, through: :creative_work_persons



    # associations
    has_many :classification_persons
    has_many :classifications, through: :classification_persons
    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups
    has_many :display_classification_aliases, -> { where("classification_aliases.internal = ?", false) }, through: :classification_groups, source: :classification_alias

    has_many :watch_list_data_hashes, as: :hashable, dependent: :destroy
    has_many :watch_lists, through: :watch_list_data_hashes

    # custom setter
    include DataSetter

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
