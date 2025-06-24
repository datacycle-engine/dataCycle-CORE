# frozen_string_literal: true

module DataCycleCore
  module ApiRenderer
    module Extensions
      module MinimalThingV4
        API_DEFAULT_ATTRIBUTES = ['@id', '@type'].freeze
        MINIMAL_ATTRIBUTES = {
          '@id' => '"things"."id"',
          '@type' => 'array_to_json("thing_templates"."api_schema_types")',
          'dct:modified' => "DATE_TRUNC('milliseconds', \"things\".\"updated_at\" AT TIME ZONE 'UTC')",
          'dct:created' => "DATE_TRUNC('milliseconds', \"things\".\"created_at\" AT TIME ZONE 'UTC')",
          'dc:touched' => "DATE_TRUNC('milliseconds', \"things\".\"cache_valid_since\" AT TIME ZONE 'UTC')"
        }.freeze

        def render_minimal_json
          selects = []
          @minimal_query = DataCycleCore::Thing.all
          selects << api_plain_context if section_visible?(:@context)

          selects << api_minimal_graph if section_visible?(:@graph)
          selects << api_plain_links_sql if section_visible?(:links) &&
                                            !@params[:permitted_params]&.dig(:page, :limit)&.to_i&.positive?
          selects << api_plain_meta_sql if section_visible?(:meta)

          ActiveRecord::Base.transaction do
            ActiveRecord::Base.connection.exec_query(
              ActiveRecord::Base.send(:sanitize_sql_array, ['SET LOCAL timezone = ?;', Time.zone.name])
            )
            result = ActiveRecord::Base.connection.select_all(
              @minimal_query.select("json_build_object(#{selects.join(', ')})").from('contents')
            )
            result&.rows&.first&.first || '{}'
          end
        end

        def render_only_context_json
          { '@context' => self.class.api_plain_context(@params[:language], @params[:expand_language]) }
        end

        def api_plain_context
          "'@context', '#{self.class.api_plain_context(@params[:language], @params[:expand_language]).to_json}'::json"
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

        def api_plain_links_sql
          return if single_thing?

          sql_query = <<-SQL.squish
            'links',
            json_strip_nulls(
              json_build_object('prev', ?, 'next', (CASE WHEN CEIL(#{total_count_sql}::float / #{thing_query.limit_value}) > #{thing_query.current_page} THEN ? ELSE NULL END))
            )
          SQL

          apply_minimal_graph_query! # if @graph is not requested, we do not need the contents

          prev_page = thing_query.current_page - 1
          next_page = thing_query.current_page + 1

          ActiveRecord::Base.send(
            :sanitize_sql_array, [
              sql_query,
              api_page_link(prev_page.positive? ? prev_page : nil),
              api_page_link(next_page)
            ]
          )
        end

        def api_plain_meta_sql
          return if single_thing?

          apply_minimal_graph_query!

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

          "'meta', json_build_object(#{sql.join(', ')})"
        end

        def total_count_sql
          total_count = '"contents"."total"'
          total_count = "MAX(#{total_count})" if section_visible?('@graph')

          total_count
        end

        def apply_minimal_graph_query!
          return if section_applied?('@graph')
          @minimal_query = @minimal_query.with(contents: thing_query.reselect(:id).except(:joins, :order, :group, :limit, :offset).reselect('COUNT("things"."id") AS "total"'))
        end

        def thing_query
          @thing_query ||= single_thing? ? DataCycleCore::Thing.where(id: @content.id).page(1).per(1) : @contents
        end

        def apply_graph_query!
          return if section_applied?('@graph')
          render_props = MINIMAL_ATTRIBUTES.slice(*requested_fields)

          query = thing_query
          query = query.joins(:thing_template) if render_props.key?('@type')
          select_fields = "json_build_object(#{render_props.map { |k, v| "'#{k}', #{v}" }.join(', ')}) AS \"data\""
          select_fields += ', COUNT(things.id) OVER () AS "total"' if section_visible?(:meta) || section_visible?(:links)

          @minimal_query = @minimal_query.with(
            contents: query.reselect(ActiveRecord::Base.send(:sanitize_sql_array, [select_fields]))
          )
        end

        def api_minimal_graph
          apply_graph_query!

          "'@graph', json_agg(\"contents\".\"data\")"
        end

        def section_applied?(section)
          return true if @applied_sections.include?(section)

          @applied_sections << section
          false
        end
      end
    end
  end
end
