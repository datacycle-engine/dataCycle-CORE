# frozen_string_literal: true

module DataCycleCore
  module Report
    module Downloads
      class DztReport < Base
        def apply(params)
          dzt_sys_id = DataCycleCore::ExternalSystem.where(identifier: ['dzt', 'onlim'])&.first&.id

          errors_only = params[:errors_only] || true
          filter_date_start = params[:by_year].present? && params[:by_month].present? ? DateTime.new(params[:by_year], params[:by_month], 1)&.beginning_of_day : nil

          return nil if dzt_sys_id.blank?

          raw_query = <<-SQL.squish
            SELECT
                syncable_id AS "thing_id",
                status,
                last_sync_at,
                last_successful_sync_at,
                CASE
                    WHEN (data->'exception'->>'timestamp')::timestamp = GREATEST(
                        (data->'exception'->>'timestamp')::timestamp,
                        COALESCE((data->>'data_send_at')::timestamp, '1970-01-01 00:00:00'::timestamp)
                    )
                    THEN data->>'exception'
                    ELSE NULL
                END AS exception,
                CASE
                    WHEN (data->>'data_send_at')::timestamp > (data->'exception'->>'timestamp')::timestamp
                    THEN data->'job_result'->'verificationReport'
                    ELSE NULL
                END AS verification_report
            FROM external_system_syncs
            WHERE external_system_id = :dzt_sys_id
              #{errors_only == true ? 'AND NOT (status IN (\'success\', \'pending\', \'running\'))' : ''}
              #{filter_date_start.present? ? ' AND last_sync_at >= :filter_date_start' : ''}
            ORDER BY last_sync_at DESC;
          SQL

          @data = ActiveRecord::Base.connection.select_all(ActiveRecord::Base.send(:sanitize_sql_for_conditions, [raw_query, { dzt_sys_id:, filter_date_start:}]))
        end
      end
    end
  end
end
