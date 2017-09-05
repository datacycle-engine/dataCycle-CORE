module DataCycleCore
  class Event < DataHash

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

    # custom setter
    include DataSetter

    include Releasable
    include ContentHelpers

    # to cash also translated values (comming from gem Globalize)
    def cache_key
      super + '-' + Globalize.locale.to_s
    end

    def destroy_translations
      self.translations.destroy_all
    end

  end
end
