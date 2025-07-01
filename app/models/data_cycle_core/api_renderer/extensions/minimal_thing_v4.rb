# frozen_string_literal: true

module DataCycleCore
  module ApiRenderer
    module Extensions
      module MinimalThingV4
        API_DEFAULT_ATTRIBUTES = ['@id', '@type'].freeze
        MINIMAL_ATTRIBUTES = {
          '@id' => '"things"."id"',
          '@type' => 'array_to_json("thing_templates"."api_schema_types")',
          'dct:modified' => "to_char(\"things\".\"updated_at\" AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.FF3TZH:TZM')",
          'dct:created' => "to_char(\"things\".\"created_at\" AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.FF3TZH:TZM')",
          'dc:touched' => "to_char(\"things\".\"cache_valid_since\" AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS.FF3TZH:TZM')"
        }.freeze

        def initialize(**)
          super

          @applied_sections = []
          @from_tables = []
          @with_tables = {}
          @selects = []
        end

        def render_minimal_json
          api_plain_context! if section_visible?(:@context)
          api_minimal_graph! if section_visible?(:@graph)
          api_plain_meta_sql! if section_visible?(:meta)
          api_plain_links_sql! if section_visible?(:links) &&
                                  !@params[:permitted_params]&.dig(:page, :limit)&.to_i&.positive?

          ActiveRecord::Base.transaction do
            ActiveRecord::Base.connection.exec_query(
              ActiveRecord::Base.send(:sanitize_sql_array, ['SET LOCAL timezone = ?;', Time.zone.name])
            )
            result = ActiveRecord::Base.connection.select_all(minimal_query)
            result&.rows&.first&.first || '{}'
          end
        end

        def minimal_query
          query = DataCycleCore::Thing.all

          @with_tables.each do |name, with_query|
            query = query.with(name => with_query)
          end

          query = query.from(@from_tables.shift)

          @from_tables.each do |table|
            query = query.joins(ActiveRecord::Base.send(:sanitize_sql_array, ["CROSS JOIN #{table}"]))
          end

          query = query.select("json_build_object(#{@selects.join(', ')})") if @selects.present?
          query
        end

        def render_only_context_json
          { '@context' => self.class.api_plain_context(@params[:language], @params[:expand_language]) }
        end

        def api_plain_context!
          @selects << "'@context', '#{self.class.api_plain_context(@params[:language], @params[:expand_language]).to_json}'::json"
        end

        private

        def single_thing?
          !@content.nil?
        end

        def section_visible?(section)
          return false if single_thing? && section.in?([:links, :meta])
          self.class.section_visible?(@params[:section_parameters], section)
        end

        def any_section_visible?
          section_visible?(:@context) ||
            section_visible?(:@graph) ||
            section_visible?(:links) ||
            section_visible?(:meta)
        end

        def requested_fields
          API_DEFAULT_ATTRIBUTES +
            Array.wrap(@params[:fields_parameters]).pluck(0) +
            Array.wrap(@params[:include_parameters]).pluck(0)
        end

        def minimal_request?
          return true unless section_visible?(:@graph)
          return false if @params[:fields_parameters].blank?

          (requested_fields - MINIMAL_ATTRIBUTES.keys).empty?
        end

        def minimal_context_request?
          minimal_request? &&
            section_visible?(:@context) &&
            !section_visible?(:@graph) &&
            !section_visible?(:links) &&
            !section_visible?(:meta)
        end

        def api_page_link(page_number)
          self.class.api_page_link(
            pagination_url: @params[:pagination_url],
            request_method: @request_method,
            permitted_params: @params[:permitted_params],
            page_number: page_number,
            page_size: thing_query.limit_value
          )
        end

        def api_plain_links_sql!
          return if single_thing?

          next_condition = apply_minimal_links_query! # if @graph is not requested, we do not need the contents

          sql_query = <<-SQL.squish
            'links',
            json_strip_nulls(
              json_build_object('prev', ?, 'next', (CASE WHEN #{next_condition} THEN ? ELSE NULL END))
            )
          SQL

          prev_page = thing_query.current_page - 1
          next_page = thing_query.current_page + 1

          @selects << ActiveRecord::Base.send(
            :sanitize_sql_array, [
              sql_query,
              api_page_link(prev_page.positive? ? prev_page : nil),
              api_page_link(next_page)
            ]
          )
        end

        def api_plain_meta_sql!
          return if single_thing?

          apply_count_query!

          total_count = total_count_sql
          sql = []
          sql << "'total', #{total_count}"
          sql << "'pages', CEIL(#{total_count}::float / #{thing_query.limit_value})" unless @params.dig(:permitted_params, :page, :limit)&.to_i&.positive?

          collection = @params[:watch_list] || @params[:stored_filter]
          if collection.present?
            sql << "'collection', '#{{
              id: collection.id,
              name: collection.name,
              slug: collection.slug,
              path: collection.try(:path)
            }.compact_blank.to_json}'::json"
          end

          @selects << "'meta', json_build_object(#{sql.join(', ')})"
        end

        def total_count_sql
          '"total_count"."total"'
        end

        def apply_count_query!
          @with_tables[:total_count] = thing_query
            .except(:joins, :order, :group, :limit, :offset)
            .reselect('COUNT("things"."id") AS "total"')
          @with_tables[:total_count] = @with_tables[:total_count].except(:where) if section_visible?(:meta) && section_visible?(:@graph)
          @from_tables << '"total_count"'
        end

        def apply_minimal_links_query!
          return "CEIL(#{total_count_sql}::float / #{thing_query.limit_value}) > #{thing_query.current_page}" if section_visible?(:meta)

          unless section_visible?(:@graph)
            @with_tables[:contents] = thing_query
              .reselect('ROW_NUMBER() OVER () AS "row_number"')
              .except(:joins, :order, :group)
              .limit(thing_query.limit_value + 1)
          end

          @with_tables[:total_count] = DataCycleCore::Thing
            .from('"contents"')
            .select('MAX("contents"."row_number") AS "total"')
          @from_tables << '"total_count"'
          "\"total_count\".\"total\" > #{thing_query.limit_value + thing_query.offset_value}"
        end

        def thing_query
          @thing_query ||= single_thing? ? DataCycleCore::Thing.where(id: @content.id).page(1).per(1) : @contents
        end

        def apply_graph_query!
          render_props = MINIMAL_ATTRIBUTES.slice(*requested_fields)

          query = thing_query
          query = query.joins(:thing_template) if render_props.key?('@type')
          select_fields = "json_build_object(#{render_props.map { |k, v| "'#{k}', #{v}" }.join(', ')}) AS \"data\""

          if section_visible?(:meta)
            @with_tables[:things] = thing_query
              .except(:order, :joins, :group, :limit, :offset)
              .reselect('"things".*')
          end

          if !section_visible?(:meta) && section_visible?(:links)
            select_fields += ", ROW_NUMBER() OVER (ORDER BY #{thing_query.arel.orders.map { |o| o.is_a?(String) ? o : o.to_sql }.join(', ')}) AS \"row_number\""
            query = query.limit(thing_query.limit_value + 1)
          end

          @with_tables[:contents] = query.reselect(ActiveRecord::Base.send(:sanitize_sql_array, [select_fields]))
          @with_tables[:contents] = @with_tables[:contents].except(:where) if section_visible?(:meta)
          @with_tables[:contents_json] = DataCycleCore::Thing
            .from('"contents"')
            .select('COALESCE(json_agg("contents"."data"), \'[]\') AS "data"')
          @with_tables[:contents_json] = @with_tables[:contents_json].where('"contents"."row_number" <= ?', thing_query.limit_value + thing_query.offset_value) if !section_visible?(:meta) && section_visible?(:links)
          @from_tables << '"contents_json"'
        end

        def api_minimal_graph!
          apply_graph_query!

          @selects << "'@graph', \"contents_json\".\"data\""
        end
      end
    end
  end
end
