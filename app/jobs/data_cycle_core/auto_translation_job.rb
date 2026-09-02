# frozen_string_literal: true

module DataCycleCore
  class AutoTranslationJob < UniqueApplicationJob
    queue_as :default
    queue_with_priority 5
    limits_concurrency key: ->(*args) { args[0] }

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
