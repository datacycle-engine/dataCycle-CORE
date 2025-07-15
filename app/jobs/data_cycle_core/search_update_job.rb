# frozen_string_literal: true

module DataCycleCore
  class SearchUpdateJob < UniqueApplicationJob
    PRIORITY = 1

    queue_as :search_update

    def priority
      PRIORITY
    end

    def delayed_reference_id
      "#{arguments[0]}_#{arguments[1].presence || 'all'}"
    end

    def perform(thing_id, locale = nil)
      content = DataCycleCore::Thing.find(thing_id)

      if locale.present?
        content.update_search_languages(false, locale.to_sym)
      else
        content.update_search_languages(true, content.first_available_locale&.to_sym)
      end
    end
  end
end
