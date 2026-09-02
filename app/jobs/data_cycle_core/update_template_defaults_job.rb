# frozen_string_literal: true

module DataCycleCore
  class UpdateTemplateDefaultsJob < UniqueApplicationJob
    TEMPLATE_DEFAULT_KEYS = [
      'data_type',
      'schema_types'
    ].freeze

    queue_as :cache_invalidation
    queue_with_priority 5
    limits_concurrency key: ->(*args) { args[0] }

    def perform(id)
      thing = DataCycleCore::Thing.find(id)

      I18n.with_locale(thing.first_available_locale) do
        data_hash = {}
        thing.add_default_values(data_hash:, force: true, keys: TEMPLATE_DEFAULT_KEYS)
        thing.set_data_hash(data_hash:, template_changed: true)
      end
    end
  end
end
