# frozen_string_literal: true

module DataCycleCore
  module ApiRenderer
    class ThingRendererV4
      JSON_RENDER_PARAMS = [
        :url_parameters,
        :section_parameters,
        :include_parameters,
        :fields_parameters,
        :field_filter,
        :classification_trees_parameters,
        :classification_trees_filter,
        :live_data,
        :language,
        :expand_language,
        :api_context,
        :api_version,
        :api_subversion,
        :full_text_search,
        :permitted_params,
        :watch_list,
        :stored_filter,
        :collection,
        :linked_stored_filter,
        :pagination_url
      ].freeze
      API_DEFAULT_ATTRIBUTES = ['@id', '@type'].freeze
      MINIMAL_ATTRIBUTES = {
        '@id' => '"things"."id"',
        '@type' => 'array_to_json("thing_templates"."api_schema_types")',
        'dct:modified' => "DATE_TRUNC('milliseconds', \"things\".\"updated_at\" AT TIME ZONE 'UTC')",
        'dct:created' => "DATE_TRUNC('milliseconds', \"things\".\"created_at\" AT TIME ZONE 'UTC')",
        'dc:touched' => "DATE_TRUNC('milliseconds', \"things\".\"cache_valid_since\" AT TIME ZONE 'UTC')"
      }.freeze

      def initialize(contents: nil, content: nil, template: nil, request_method: 'GET', **params)
        @content = content
        @contents = contents
        @params = params
        @template = template
        @request_method = request_method || 'GET'
      end

      def render(render_format = :json)
        send(:"render_#{render_format}")
      end

      def json_template
        return @template if @template
        return 'data_cycle_core/api/v4/contents/show' if @content

        'data_cycle_core/api/v4/contents/index'
      end

      def json_params
        params = @params.slice(*JSON_RENDER_PARAMS)
        params[:url_parameters] ||= {}
        params[:section_parameters] ||= {}
        params[:include_parameters] ||= []
        params[:fields_parameters] ||= []
        params[:field_filter] = params[:fields_parameters].present?
        params[:classification_trees_parameters] ||= []
        params[:classification_trees_filter] = params[:classification_trees_parameters].present?
        params[:language] ||= Array(I18n.default_locale.to_s)
        params[:expand_language] ||= false
        params[:api_context] ||= 'api'
        params[:api_version] = 4
        params[:permitted_params] ||= {}

        params[:content] = @content if @content

        if @contents
          params[:contents] = @contents
          params[:pagination_contents] = @contents
          params[:count] = @count
        end

        params.merge(@params[:additional_params] || {})
      end

      def renderer
        @renderer ||= DataCycleCore::Api::V4::ContentsController.renderer.new(
          http_host: Rails.application.config.action_mailer.default_url_options[:host],
          https: Rails.application.config.force_ssl
        )
      end

      def render_json
        return render_only_context_json if minimal_context_request?
        return render_minimal_json if minimal_request?

        renderer.render_to_string(
          assigns: json_params,
          template: json_template,
          layout: false
        )
      end

      def render_minimal_json
        selects = []
        @minimal_query = DataCycleCore::Thing.all
        selects << api_plain_context if section_visible?(:@context)

        selects << api_minimal_graph if section_visible?(:@graph)
        selects << api_plain_links_sql if section_visible?(:links) && !@params[:permitted_params]&.dig(:page, :limit)&.to_i&.positive?
        selects << api_plain_meta_sql if section_visible?(:meta)

        @minimal_query = @minimal_query.from('(VALUES(NULL))') unless section_visible?(:meta) || section_visible?(:links)

        ActiveRecord::Base.transaction do
          ActiveRecord::Base.connection.exec_query(
            ActiveRecord::Base.send(:sanitize_sql_array, ['SET LOCAL timezone = ?;', Time.zone.name])
          )
          result = ActiveRecord::Base.connection.select_all(
            @minimal_query.select("json_build_object(#{selects.join(', ')})")
          )
          result.rows.first.first
        end
      end

      def render_only_context_json
        return {} unless section_visible?(:@context)
        { '@context' => self.class.api_plain_context(@params[:language], @params[:expand_language]) }
      end

      def api_plain_context
        "'@context', '#{self.class.api_plain_context(@params[:language], @params[:expand_language]).to_json}'::json"
      end

      def self.api_plain_context(languages, expanded = false)
        display_language = nil
        display_language = languages if languages.is_a?(::String)
        display_language = languages.first if languages.is_a?(::Array) && languages.size == 1 && languages.first.is_a?(::String)
        display_language = I18n.default_locale if languages.blank?
        display_language = nil if expanded

        [
          'https://schema.org/',
          {
            '@base' => "#{DataCycleCore::UrlService.instance.api_v4_universal_url}/",
            '@language' => display_language,
            'skos' => 'https://www.w3.org/2009/08/skos-reference/skos.html#',
            'dct' => 'http://purl.org/dc/terms/',
            'cc' => 'http://creativecommons.org/ns#',
            'dc' => 'https://schema.datacycle.at/',
            'dcls' => "#{DataCycleCore::UrlService.instance.schema_url}/",
            'odta' => 'https://odta.io/voc/',
            'sdm' => 'https://smartdatamodels.org/',
            'alps' => 'http://json-schema.org/draft-07/schema/destinationdata/schemas/2022-04/datatypes#/definitions/'
          }.compact
        ]
      end

      def self.api_plain_meta(contents: nil, collection: nil, permitted_params: {}, count: nil, pages: nil)
        response_data = { total: contents&.total_count || count }
        response_data[:pages] = contents&.total_pages || pages unless permitted_params.dig(:page, :limit)&.to_i&.positive?

        if collection.present?
          response_data[:collection] = {
            id: collection.id,
            name: collection.name,
            slug: collection.slug,
            path: collection.try(:path)
          }.compact_blank
        end

        response_data
      end

      def self.api_page_link(pagination_url: nil, request_method: 'GET', permitted_params: {}, page_number: 1, page_size: 25)
        return if page_number.nil?

        object_url = ->(params) { pagination_url&.call(params) }
        common_params = if request_method == 'POST'
                          {}
                        else
                          permitted_params.to_h.except('id', 'format', 'page', 'api_subversion')
                        end
        common_params = common_params.merge(page: { offset: permitted_params.dig(:page, :offset).to_i }) if permitted_params&.dig(:page, :offset)&.to_i&.positive?

        object_url.call(common_params.merge(page: { number: page_number, size: page_size }))
      end

      def self.api_plain_links(contents: nil, **args)
        links = {}
        links[:prev] = api_page_link(page_number: contents.prev_page, page_size: contents.limit_value, **args) if contents.prev_page
        links[:next] = api_page_link(page_number: contents.next_page, page_size: contents.limit_value, **args) if contents.next_page
        links
      end

      def self.section_visible?(section_params, section)
        return false if section.nil?
        return true if section_params.blank?

        !section_params[section.to_sym]&.to_i&.zero?
      end

      private

      def section_visible?(section)
        self.class.section_visible?(@params[:section_parameters], section)
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
          page_size: @contents.limit_value
        )
      end

      def api_plain_links_sql
        sql_query = <<-SQL.squish
            'links',
            json_strip_nulls(
              json_build_object('prev', ?, 'next', (CASE WHEN full_count.has_next THEN ? ELSE NULL END))
            )
        SQL

        apply_minimal_graph_query! unless section_visible?(:@graph) || section_visible?(:meta) # if @graph is not requested, we do not need the contents
        apply_full_count_from_contents! unless section_visible?(:meta) # if count ist not available, use contents to determine if there is a next page

        prev_page = @contents.current_page - 1
        next_page = @contents.current_page + 1

        ActiveRecord::Base.send(
          :sanitize_sql_array, [
            sql_query,
            api_page_link(prev_page.positive? ? prev_page : nil),
            api_page_link(next_page)
          ]
        )
      end

      def api_plain_meta_sql
        apply_full_count!

        sql = []
        sql << "'total', full_count.total"
        sql << "'pages', full_count.pages" unless @params.dig(:permitted_params, :page, :limit)&.to_i&.positive?

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

      def apply_full_count_from_contents!
        @minimal_query = @minimal_query.from('full_count').with(full_count: DataCycleCore::Thing.from('contents').select("COUNT(*) > #{@contents.limit_value} AS \"has_next\""))
      end

      def apply_full_count!
        select_sql = <<-SQL.squish
          COUNT("things"."id") AS "total",
          CEIL(COUNT("things"."id")::float / #{@contents.limit_value}) AS "pages",
          CEIL(COUNT("things"."id")::float / #{@contents.limit_value}) > #{@contents.current_page} AS "has_next"
        SQL
        @minimal_query = @minimal_query.from('full_count')
          .with(
            full_count:
            @contents.reorder(nil).except(:joins, :limit, :offset, :order, :group).select(select_sql)
          )
      end

      def apply_minimal_graph_query!
        query = @contents.limit(@contents.limit_value + 1)
        @minimal_query = @minimal_query.with(contents: query.reselect(:id).except(:joins, :order, :group))
      end

      def apply_graph_query!
        render_props = MINIMAL_ATTRIBUTES.slice(*requested_fields)

        query = @contents
        query = query.joins(:thing_template) if render_props.key?('@type')
        query = query.limit(@contents.limit_value + 1)
        select_fields = "json_build_object(#{render_props.map { |k, v| "'#{k}', #{v}" }.join(', ')}) AS \"data\", row_number() over () AS \"row_number\""

        @minimal_query = @minimal_query.with(
          contents: query.reselect(ActiveRecord::Base.send(:sanitize_sql_array, [select_fields]))
        )
      end

      def api_minimal_graph
        apply_graph_query!

        "'@graph', (SELECT json_agg(\"contents\".\"data\") FROM \"contents\" WHERE \"contents\".\"row_number\" <= #{@contents.offset_value + @contents.limit_value})"
      end
    end
  end
end

ActiveSupport.run_load_hooks :data_cycle_api_renderer_thing_renderer, DataCycleCore::ApiRenderer::ThingRendererV4
