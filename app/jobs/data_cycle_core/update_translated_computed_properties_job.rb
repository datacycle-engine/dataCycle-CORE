# frozen_string_literal: true

module DataCycleCore
  class UpdateTranslatedComputedPropertiesJob < UniqueApplicationJob
    # Same starved tier as DataCycleCore::UpdateComputedPropertiesJob - see the note there. Priority
    # matched to its siblings so it does not sort ahead of them on the strength of the
    # DataCycleCore::ApplicationJob default it used to inherit.
    queue_as :content_maintenance
    queue_with_priority 12
    limits_concurrency key: ->(*args) { "#{args[0]}/#{args[1].join(',')}/#{args[2]&.join(',')}" }

    def perform(id, locales, keys = nil)
      content = DataCycleCore::Thing.find_by(id:)

      return if content.nil?

      update_computed_properties(content, locales, keys)
    end

    private

    def update_computed_properties(content, locales, keys)
      return if keys.blank? || locales.blank?

      computed_keys = content.computed_property_names.intersection(keys)
      computed_keys = computed_keys.intersection(content.translatable_property_names)

      return if computed_keys.blank?

      content.available_locales.map(&:to_s).intersection(locales).each do |locale|
        content.update_computed_values_for_locale(keys: computed_keys, locale: locale)
      end
    end
  end
end
