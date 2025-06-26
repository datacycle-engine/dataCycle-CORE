# frozen_string_literal: true

module DataCycleCore
  module ApiRenderer
    class ThingRendererV4
      prepend Extensions::MinimalThingV4

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
        return '{}' unless any_section_visible?
        return render_only_context_json if minimal_context_request?
        return render_minimal_json if minimal_request?

        renderer.render_to_string(
          assigns: json_params,
          template: json_template,
          layout: false
        )
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

      def self.api_page_link(pagination_url: nil, request_method: 'GET', permitted_params: {}, page_number: 1, page_size: 25, object_url: nil)
        return if page_number.nil?

        object_url ||= ->(_) {}
        object_url = ->(params) { pagination_url.call(params) } if pagination_url.present?
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
    end
  end
end

ActiveSupport.run_load_hooks :data_cycle_api_renderer_thing_renderer, DataCycleCore::ApiRenderer::ThingRendererV4
