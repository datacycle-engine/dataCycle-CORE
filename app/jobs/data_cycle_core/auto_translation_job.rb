# frozen_string_literal: true

module DataCycleCore
  class AutoTranslationJob < UniqueApplicationJob
    PRIORITY = 5

    queue_as :default

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def perform(id, locale)
      return unless DataCycleCore::Feature::AutoTranslation.enabled?

      thing = DataCycleCore::Thing.find_by(id:)
      I18n.with_locale(locale) do
        thing&.create_update_translations
        thing&.create_update_auto_translations
      end
    end
  end
end
