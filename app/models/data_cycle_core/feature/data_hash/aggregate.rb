# frozen_string_literal: true

module DataCycleCore
  module Feature
    module DataHash
      module Aggregate
        def before_destroy_data_hash(_options)
          super

          try(MasterData::Templates::AggregateTemplate::AGGREGATE_PROPERTY_NAME)&.update_all(cache_valid_since: Time.zone.now, aggregate_type: 'default')
        end

        def before_save_data_hash(options)
          super

          return unless options.new_content && DataCycleCore::Feature::Aggregate.aggregate?(self)

          self.aggregate_type = 'aggregate'
        end

        def after_save_data_hash(options)
          super

          return unless aggregate_type_aggregate?

          changed_aggregates = previous_datahash_changes&.dig(MasterData::Templates::AggregateTemplate::AGGREGATE_PROPERTY_NAME).to_h { |v| v.first(2) }

          DataCycleCore::Thing.where(id: changed_aggregates['+']).update_all(cache_valid_since: Time.zone.now, aggregate_type: 'belongs_to_aggregate') if changed_aggregates['+'].present?
          DataCycleCore::Thing.where(id: changed_aggregates['-']).update_all(cache_valid_since: Time.zone.now, aggregate_type: 'default') if changed_aggregates['-'].present?

          return unless options.new_content

          missing_locales = aggregate_for.flat_map(&:translated_locales).uniq - translated_locales
          missing_locales.each do |locale|
            I18n.with_locale(locale) do
              set_data_hash(data_hash: { aggregate_for: aggregate_for.map(&:id) })
            end
          end
        end
      end
    end
  end
end
