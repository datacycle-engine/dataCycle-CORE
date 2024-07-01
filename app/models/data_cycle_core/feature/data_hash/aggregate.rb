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

          changed_aggregates = previous_datahash_changes&.dig(MasterData::Templates::AggregateTemplate::AGGREGATE_PROPERTY_NAME).to_h
          DataCycleCore::Thing.where(id: changed_aggregates['+']).update_all(cache_valid_since: Time.zone.now, aggregate_type: 'belongs_to_aggregate') if changed_aggregates['+'].present?
          DataCycleCore::Thing.where(id: changed_aggregates['-']).update_all(cache_valid_since: Time.zone.now, aggregate_type: 'default') if changed_aggregates['-'].present?
        end
      end
    end
  end
end
