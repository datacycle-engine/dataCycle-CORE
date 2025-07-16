# frozen_string_literal: true

module DataCycleCore
  module ApiRenderer
    class TimeseriesRenderer
      DEFAULT_GROUPS = ['hour', 'day', 'week', 'month', 'quarter', 'year'].freeze
      DEFAULT_AGGREGATE_FUNCTIONS = ['SUM', 'MIN', 'MAX', 'AVG'].freeze

      attr_reader :query

      def initialize(content:, timeseries: nil, time: nil, group_by: nil, data_format: nil)
        @from = time&.dig(:in, :min).presence&.then { |t| Time.zone.parse(t) }
        @to = time&.dig(:in, :max).presence&.then { |t| Time.zone.parse(t) }
        @data_format = data_format || 'array'
        @timezone = Time.zone.now.time_zone.name

        unless content.timeseries_property_names.include?(timeseries)
          @error = "no timeseries data found for #{content.name}(#{content.id})"
          return
        end

        @query = content.send(timeseries)

        group_by.prepend('sum_') if group_by&.in?(DEFAULT_GROUPS) # required for legacy group_by without aggregeate_function prefix

        if group_by.present? && !respond_to?(group_by)
          @error = "wrong groupBy parameter #{content.name}(#{content.id}) -> #{group_by}"
          return
        end

        @group_by = group_by.presence || 'default'
      end

      def render(render_format)
        raise Error::RendererError, @error if @error.present?

        transform_data(render_format.to_s)
      end

      def group_and_filter_query
        # ensure the from and to parameters still have timezone information in the query
        @query = query.where('timestamp >= (?)::timestamptz', @from.iso8601) if @from.present?
        @query = query.where('timestamp <= (?)::timestamptz', @to.iso8601) if @to.present?

        @query = send(@group_by)
      end

      def sql_for_data_format(combined_format)
        return send(:"#{combined_format}_#{@group_by}") if @group_by.present? && respond_to?(:"#{combined_format}_#{@group_by}")

        return send(combined_format) if respond_to?(combined_format)

        raise Error::RendererError, "Combination Format/dataFormat not allowed: #{combined_format}"
      end

      def transform_data(data_format)
        group_and_filter_query

        ActiveRecord::Base.transaction do
          ActiveRecord::Base.connection.exec_query(
            ActiveRecord::Base.send(:sanitize_sql_array, ['SET LOCAL timezone = ?;', Time.zone.name])
          )

          ActiveRecord::Base.connection.select_all(
            Arel.sql(
              sql_for_data_format("#{data_format}_#{@data_format}")
            )
          ).first&.values&.first
        end
      end

      def csv_array
        <<-SQL.squish
          SELECT concat('timestamp; value', chr(10), string_agg(concat(to_json(ts.ts), '; ', ts.value::text), chr(10)))
          FROM (#{query.to_sql}) ts
        SQL
      end

      def json_array
        scale_sql = ", 'meta', JSON_BUILD_OBJECT('scale_x', '#{@scale_x}')" if @scale_x.present?

        <<-SQL.squish
          SELECT json_build_object('data', json_agg(json_build_array(ts.ts, ts.value))#{scale_sql})
          FROM (#{query.to_sql}) ts
        SQL
      end

      def json_object
        scale_sql = ", 'meta', JSON_BUILD_OBJECT('scale_x', '#{@scale_x}')" if @scale_x.present?

        <<-SQL.squish
          SELECT json_build_object('data', json_agg(json_build_object('x', ts.ts, 'y', ts.value))#{scale_sql})
          FROM (#{query.to_sql}) ts
        SQL
      end

      def default
        query.select('timeseries.timestamp AS ts, timeseries.value')
      end

      def group_by_function(group, aggregate_function)
        @scale_x = group

        query
          .select("DATE_TRUNC('#{group}', timeseries.timestamp, '#{@timezone}') AS ts, #{aggregate_function}(timeseries.value) AS value")
          .group(:ts)
          .reorder(ts: :asc)
      end

      DEFAULT_AGGREGATE_FUNCTIONS.each do |aggregate_function|
        DEFAULT_GROUPS.each do |group|
          define_method(:"#{aggregate_function.underscore}_#{group.underscore}") do
            group_by_function(group, aggregate_function)
          end
        end
      end
    end
  end
end

ActiveSupport.run_load_hooks :data_cycle_api_renderer_timeseries_renderer, DataCycleCore::ApiRenderer::TimeseriesRenderer
