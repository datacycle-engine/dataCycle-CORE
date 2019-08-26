# frozen_string_literal: true

module DataCycleCore
  module Serialize
    class JsonSerializer
      class << self
        def translatable?
          true
        end

        def mime_type(_content)
          'application/json'
        end

        def file_extension(_mime_type)
          '.json'
        end

        def serialize(content, language)
          DataCycleCore::Api::V3::ContentsController.renderer.new(
            http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
            https: Rails.application.config.force_ssl
          ).render(
            assigns: { content: content, language: language, include_parameters: [], mode_parameters: [], api_version: 3 },
            template: 'data_cycle_core/api/v3/contents/show',
            layout: false
          )
        end

        def serialize_watch_list(watch_list, language)
          pagination_contents = watch_list.watch_list_data_hashes.order(created_at: :desc).page(1).per(watch_list.watch_list_data_hashes.count)
          DataCycleCore::Api::V3::WatchListsController.renderer.new(
            http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
            https: Rails.application.config.force_ssl
          ).render(
            assigns: { contents: pagination_contents, watch_list: watch_list, language: language, include_parameters: [], mode_parameters: [], api_version: 3 },
            template: 'data_cycle_core/api/v3/watch_lists/show',
            layout: false
          )
        end

        def serialize_stored_filter(stored_filter, language)
          contents = stored_filter.apply
          pagination_contents = contents.page(1).per(contents.count)
          DataCycleCore::Api::V3::ContentsController.renderer.new(
            http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
            https: Rails.application.config.force_ssl
          ).render(
            assigns: { contents: pagination_contents, language: language, include_parameters: [], mode_parameters: [], api_version: 3 },
            template: 'data_cycle_core/api/v3/contents/index',
            layout: false
          )
        end
      end
    end
  end
end
