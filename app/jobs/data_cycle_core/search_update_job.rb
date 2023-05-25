# frozen_string_literal: true

module DataCycleCore
  class SearchUpdateJob < UniqueApplicationJob
    PRIORITY = 0

    queue_as :search_update

    def priority
      PRIORITY
    end

    def delayed_reference_id
      "#{arguments[1]}_#{arguments[2].presence || 'all'}"
    end

    def delayed_reference_type
      arguments[0]
    end

    def perform(class_name, content_id, locale)
      content = class_name.classify.constantize.find_by(id: content_id)

      if content && locale.present?
        content.update_search_languages(false, locale.to_sym)
      elsif content
        content.update_search_languages(true, content.first_available_locale&.to_sym)
      end
    end
  end
end
