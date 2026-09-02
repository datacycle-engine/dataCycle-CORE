# frozen_string_literal: true

module DataCycleCore
  class SearchUpdateJob < UniqueApplicationJob
    queue_as :search_update
    queue_with_priority 1
    limits_concurrency key: ->(*args) { "#{args[0]}_#{args[1].presence || 'all'}" }

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
