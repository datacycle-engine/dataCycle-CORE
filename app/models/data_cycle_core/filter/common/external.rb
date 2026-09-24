# frozen_string_literal: true

module DataCycleCore
  module Filter
    module Common
      module External
        def with_external_system
          reflect(
            @query.where.not(thing[:external_source_id].eq(nil))
          )
        end

        def not_with_external_system
          reflect(
            @query.where(thing[:external_source_id].eq(nil))
          )
        end

        def external_source(ids = nil)
          return self if ids.blank?

          ids = ids.clone
          includes_nil = Array.wrap(ids).delete('nil').present?
          where_clause = thing[:external_source_id].in(ids)
          where_clause = where_clause.or(thing[:external_source_id].eq(nil)) if includes_nil

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

        def external_system(ids = nil, type = 'import')
          return self if ids.blank?
          return external_source(ids) if type == 'import'

          if type == 'all'
            reflect(
              @query.where(sync_exists(external_system_ids: ids)).or(
                @query.where(external_source_id: ids)
              )
            )
          else
            reflect(@query.where(sync_exists(external_system_ids: ids, sync_type: type)))
          end
        end

        def not_external_system(ids = nil, type = 'import')
          return self if ids.blank?
          return not_external_source(ids) if type == 'import'

          if type == 'all'
            reflect(
              @query
                .where.not(external_source_id: ids)
                .or(@query.where(external_source_id: nil))
                .where.not(sync_exists(external_system_ids: ids))
            )
          else
            reflect(@query.where.not(sync_exists(external_system_ids: ids, sync_type: type)))
          end
        end

        # Contents having an export sync that matches both selections at once, so that
        # {'status' => ['error', 'failure']} lists everything whose export failed. #external_system
        # with type 'export' answers only whether a content was exported at all, never with which
        # result.
        # @param value [Hash] 'status', a list and required, optionally narrowed by a list of
        #   'external_system_ids' (see #export_status_values for why the status carries the filter)
        def export_status(value = nil)
          statuses = export_status_values(value)
          return self if statuses.blank?

          reflect(@query.where(export_status_subquery(value, statuses:)))
        end

        # Contents exported to the selected systems, but to none of them with one of the selected
        # statuses - "exported to feratel, just not successfully". Deliberately not the plain
        # complement of #export_status: that also matches every content never exported at all, so
        # "enthält nicht / feratel / Erfolgreich" would bury the handful of failed exports under
        # everything that was never sent to feratel in the first place.
        def not_export_status(value = nil)
          statuses = export_status_values(value)
          return self if statuses.blank?

          reflect(@query.where(export_status_subquery(value)).where.not(export_status_subquery(value, statuses:)))
        end

        private

        # The correlated EXISTS over external_system_syncs that #external_system, #not_external_system
        # and #export_status_subquery all need. The alternative, `things.id IN (subquery)`, plans worse
        # in some cases once a sort is in play - the random sort the dashboard offers in particular.
        #
        # @param external_system_ids [Array] blank leaves the system open, which #export_status needs
        #   for a status selected without a system
        # @param sync_type [String, nil] nil leaves the type open, which #external_system's 'all' mode
        #   needs to count a sync of any type
        # @param statuses [Array, nil] nil leaves the status open; [nil] matches a sync that never
        #   reported one, the sentinel #export_status_values produces
        # @return [Arel::Nodes::Exists]
        def sync_exists(external_system_ids:, sync_type: nil, statuses: nil)
          subquery = DataCycleCore::ExternalSystemSync.all
          subquery = subquery.where(external_system_id: external_system_ids) if external_system_ids.present?
          subquery = subquery.where(sync_type:) if sync_type.present?
          subquery = subquery.where(external_system_sync[:syncable_id].eq(thing[:id]))
          subquery = subquery.where(status: statuses) if statuses.present?

          subquery.select(1).arel.exists
        end

        # The value is a Hash by the time this runs: #export_status_values answers [] for anything
        # else, and both callers return on that before building a subquery.
        #
        # @param statuses [Array, nil] nil builds the "is exported to these systems" half alone,
        #   which #not_export_status needs as the population it then narrows
        # @return [Arel::Nodes::Exists]
        def export_status_subquery(value, statuses: nil)
          sync_exists(
            external_system_ids: Array.wrap(value['external_system_ids']).compact_blank,
            sync_type: 'export',
            statuses:
          )
        end

        # The statuses a value selects, and with that the whole filter: the systems only narrow it,
        # so a value selecting none asks exactly what #external_system with type 'export' already
        # answers. #export_status and #not_export_status both return self on [], and
        # DataCycleCore::StoredFilter.narrows_nothing? drops the filter from the form on the same
        # answer, so the dashboard shows no chip over a result it did not narrow.
        #
        # The drop asks this method rather than inspecting `v` itself because `v` reaches it as jsonb
        # from a stored filter or a hand-built url, not only as the Hash the form builds. A bare
        # ['error'] carries no 'status' key to find, and a status of `false` counts as present to
        # DataHashService.blank? while compact_blank discards it. A second, parallel check reads
        # either shape as a selection and keeps a filter the query never narrowed.
        #
        # 'nil' stands for a sync that never reported a result, mirroring the sentinel
        # #external_source accepts for a content without an external source. Rails turns the nil
        # element into `status IS NULL`, OR-ed with the IN list.
        def export_status_values(value)
          return [] unless value.is_a?(::Hash)

          Array.wrap(value['status']).compact_blank.map { |s| s == 'nil' ? nil : s }
        end

        module_function :export_status_values
      end
    end
  end
end
