# frozen_string_literal: true

module DataCycleCore
  module ApiRenderer
    class StatisticsRenderer
      DEFAULT_GROUPS = ['hour', 'day', 'week', 'month', 'quarter', 'year'].freeze
      DEFAULT_AGGREGATE_FUNCTIONS = ['COUNT'].freeze
      ALLOWED_ATTRIBUTES = {
        'dct:created' => 'created_at',
        'dct:modified' => 'updated_at'
      }.freeze

      attr_reader :query, :attribute

      def initialize(query:, attribute: nil, time: nil, group_by: nil, data_format: nil)
        @from = time&.dig(:in, :min).presence&.then { |t| Time.zone.parse(t) }
        @to = time&.dig(:in, :max).presence&.then { |t| Time.zone.parse(t) }
        @data_format = data_format || 'array'
        @timezone = Time.zone.now.time_zone.name

        unless ALLOWED_ATTRIBUTES.key?(attribute)
          @error = "attribute '#{attribute}' not found!"
          return
        end

        @attribute = ALLOWED_ATTRIBUTES[attribute]
        @query = query.reorder(nil)

        group_by.prepend('count_') if group_by&.in?(DEFAULT_GROUPS)

        if group_by.present? && !respond_to?(group_by)
          @error = "wrong groupBy parameter -> #{group_by}"
          return
        end

        @group_by = group_by.presence || 'default'
      end

      def render(render_format)
        raise Error::RendererError, @error if @error.present?

        transform_data(render_format.to_s)
      end

      def group_and_filter_query
        @query = query.where(ActiveRecord::Base.send(:sanitize_sql_array, ["#{attribute} >= ?", @from])) if @from.present?
        @query = query.where(ActiveRecord::Base.send(:sanitize_sql_array, ["#{attribute} <= ?", @to])) if @to.present?
        @query = send(@group_by)
      end

      def sql_for_data_format(combined_format)
        return send(:"#{combined_format}_#{@group_by}") if @group_by.present? && respond_to?(:"#{combined_format}_#{@group_by}")

        return send(combined_format) if respond_to?(combined_format)

        raise Error::RendererError, "Combination Format/dataFormat not allowed: #{combined_format}"
      end

      def transform_data(data_format)
        group_and_filter_query

        ActiveRecord::Base.connection.select_all(
          Arel.sql(
            sql_for_data_format("#{data_format}_#{@data_format}")
          )
        ).first&.values&.first
      end

      def csv_array
        <<-SQL.squish
          SELECT concat('timestamp; value', chr(10), string_agg(concat(to_json(ts.ts), '; ', ts.value::text), chr(10)))
          FROM (#{query.to_sql}) ts
        SQL
      end

      def json_array
        scale_sql = ", 'meta', JSON_BUILD_OBJECT('scaleX', '#{@scale_x}')" if @scale_x.present?

        <<-SQL.squish
          SELECT json_build_object('data', json_agg(json_build_array(ts.ts, ts.value))#{scale_sql})
          FROM (#{query.to_sql}) ts
        SQL
      end

      def json_object
        scale_sql = ", 'meta', JSON_BUILD_OBJECT('scaleX', '#{@scale_x}')" if @scale_x.present?

        <<-SQL.squish
          SELECT json_build_object('data', json_agg(json_build_object('x', ts.ts, 'y', ts.value))#{scale_sql})
          FROM (#{query.to_sql}) ts
        SQL
      end

      def default
        query
          .select("things.#{attribute} AS ts, things.id AS value")
          .reorder(attribute.to_sym => :asc)
      end

      def group_by_function(group, aggregate_function)
        @scale_x = group

        query
          .select("DATE_TRUNC('#{group}', things.#{attribute}, '#{@timezone}') AS ts, #{aggregate_function}(things.id) AS value")
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

ActiveSupport.run_load_hooks :data_cycle_api_renderer_statistics_renderer, DataCycleCore::ApiRenderer::StatisticsRenderer
