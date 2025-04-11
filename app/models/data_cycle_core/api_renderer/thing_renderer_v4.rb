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

      def initialize(contents: nil, content: nil, template: nil, **params)
        @content = content
        @contents = contents
        @params = params
        @template = template
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

      def render_json
        @renderer = DataCycleCore::Api::V4::ContentsController.renderer.new(
          http_host: Rails.application.config.action_mailer.default_url_options[:host],
          https: Rails.application.config.force_ssl
        )

        @renderer.render_to_string(
          assigns: json_params,
          template: json_template,
          layout: false
        )
      end
    end
  end
end

ActiveSupport.run_load_hooks :data_cycle_api_renderer_thing_renderer, DataCycleCore::ApiRenderer::ThingRendererV4
