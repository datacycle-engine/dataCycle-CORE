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
        :section_parameters,
        :language,
        :expand_language,
        :api_context,
        :api_version,
        :api_subversion,
        :full_text_search,
        :permitted_params,
        :watch_list,
        :stored_filter
      ].freeze

      def initialize(contents:, single_item: false, **params)
        @contents = contents
        @single_item = single_item
        @params = params
      end

      def render(render_format = :json)
        send("render_#{render_format}")
      end

      def json_template
        @single_item ? 'data_cycle_core/api/v4/contents/show' : 'data_cycle_core/api/v4/contents/index'
      end

      def json_params
        params = @params.slice(*JSON_RENDER_PARAMS)

        if @single_item
          params[:content] = @contents.first
        else
          params[:contents] = @contents
          params[:pagination_contents] = @contents
        end

        params
      end

      def render_json
        @renderer = DataCycleCore::Api::V4::ContentsController.renderer.new(
          http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
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
