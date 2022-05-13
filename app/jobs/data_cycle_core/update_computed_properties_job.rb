# frozen_string_literal: true

module DataCycleCore
  class UpdateComputedPropertiesJob < UniqueApplicationJob
    PRIORITY = 12
    WEBHOOK_PRIORITY = 6

    queue_as :cache_invalidation

    def priority
      PRIORITY
    end

    def delayed_reference_id
      arguments[0]
    end

    def delayed_reference_type
      DataCycleCore::Thing.name
    end

    def perform(content_id)
      DataCycleCore::Thing
        .where(id: load_depending_content_ids(content_id))
        .find_each { |thing| update_computed_properties(thing) }
    end

    private

    def load_depending_content_ids(content_id)
      ActiveRecord::Base.connection.execute(
        ActiveRecord::Base.send(
          :sanitize_sql_array,
          [
            'SELECT DISTINCT content_id FROM content_property_dependencies WHERE dependent_content_id = ?',
            content_id
          ]
        )
      ).values.flatten
    end

    def update_computed_properties(content)
      if (content.computed_property_names & content.translatable_property_names).present?
        content.available_locales.each do |locale|
          I18n.with_locale(locale) do
            content.webhook_priority = WEBHOOK_PRIORITY
            content.set_data_hash(data_hash: content.get_data_hash.except(*content.computed_property_names))
          end
        end
      else
        I18n.with_locale(content.first_available_locale) do
          content.webhook_priority = WEBHOOK_PRIORITY
          content.set_data_hash(data_hash: content.get_data_hash.except(*content.computed_property_names))
        end
      end
    end
  end
end
