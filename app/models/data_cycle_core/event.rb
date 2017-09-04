module DataCycleCore
  class Event < DataHash
    class Translation < Globalize::ActiveRecord::Translation
        include ContentTranslationHelpers
    end

    # handle translations with gem Globalize
    translates :headline, :description, :content, :properties, :release,
      :release_id, :release_comment

    # callbacks
    before_destroy :destroy_translations, prepend: true

    # associations
    belongs_to :external_source

    has_many :creative_work_events, dependent: :destroy
    has_many :creative_works, through: :creative_work_events

    has_many :event_persons, dependent: :destroy
    has_many :persons, through: :event_persons

    has_many :event_places, dependent: :destroy
    has_many :places, through: :event_places

    has_many :classification_events, dependent: :destroy
    has_many :classifications, through: :classification_events

    has_many :classification_groups, through: :classifications
    has_many :classification_aliases, through: :classification_groups
    has_many :display_classification_aliases, -> { where("classification_aliases.internal = ?", false) }, through: :classification_groups, source: :classification_alias

    # custom setter
    include DataSetter

    include Releasable
    include ContentHelpers


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
