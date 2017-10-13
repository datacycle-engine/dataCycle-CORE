module DataCycleCore
  module SearchHelper

    def seed_search

      DataCycleCore.content_tables.each do |content_name|
        "DataCycleCore::#{content_name.classify}".safe_constantize.all.each do |content_object|
          content_object.translated_locales.each do |localization|
            I18n.with_locale(localization) do
              content_object.set_search
            end
          end
        end
      end

    end

  end
end
