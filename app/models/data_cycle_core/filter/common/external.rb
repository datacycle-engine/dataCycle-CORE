# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module External
        def external_source(ids = nil)
          return self if ids.blank?
          dc_created = Array.wrap(ids).detect { |i| i == 'nil' }
          where_clause = thing[:external_source_id].in(ids)
          where_clause = where_clause.or(thing[:external_source_id].eq(nil)) if dc_created.present?
          reflect(
            @query.where(where_clause)
          )
        end

        def not_external_source(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(thing[:external_source_id].not_in(ids).or(thing[:external_source_id].eq(nil)))
          )
        end

        def with_external_source_names(definition)
          return self if definition.blank?
          raise StandardError, 'Missing data definition: names' if definition.dig('names').blank?

          ids = DataCycleCore::ExternalSystem.where(name: definition.dig('names').flatten)&.map(&:id)

          external_source(ids)
        end

        def without_external_sources(definition)
          return self if definition.blank?
          without_external_source
        end

        def without_external_source
          reflect(
            @query.where(thing[:external_source_id].eq(nil))
          )
        end

        def external_system(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(external_system_sync.where(external_system_sync[:external_system_id].in(ids).and(external_system_sync[:syncable_id].eq(thing[:id]))).exists)
          )
        end

        def not_external_system(ids = nil)
          return self if ids.blank?

          reflect(
            @query.where(external_system_sync.where(external_system_sync[:external_system_id].in(ids).and(external_system_sync[:syncable_id].eq(thing[:id]))).exists.not)
          )
        end
      end
    end
  end
end
