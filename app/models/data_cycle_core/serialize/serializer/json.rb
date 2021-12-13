# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module Serializer
      class Json < Base
        class << self
          def translatable?
            true
          end

          def mime_type(_serialized_content = nil, _content = nil)
            'application/json'
          end

          def serialize_thing(content, language)
            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [
                DataCycleCore::Serialize::SerializedData::Content.new(
                  data:
                    DataCycleCore::Api::V3::ContentsController.renderer.new(
                      http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
                      https: Rails.application.config.force_ssl
                    ).render(
                      assigns: { content: content, language: language, include_parameters: [], mode_parameters: [], api_version: 3 },
                      template: 'data_cycle_core/api/v3/contents/show',
                      layout: false
                    ),
                  mime_type: mime_type,
                  file_name: file_name(content, language),
                )
              ]
            )
          end

          def serialize_watch_list(watch_list, language)
            pagination_contents = watch_list.watch_list_data_hashes.order(created_at: :desc).page(1).per(watch_list.watch_list_data_hashes.count)
            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [
                DataCycleCore::Serialize::SerializedData::Content.new(
                  data:
                    DataCycleCore::Api::V3::WatchListsController.renderer.new(
                      http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
                      https: Rails.application.config.force_ssl
                    ).render(
                      assigns: { contents: pagination_contents, watch_list: watch_list, language: language, include_parameters: [], mode_parameters: [], api_version: 3 },
                      template: 'data_cycle_core/api/v3/watch_lists/show',
                      layout: false
                    ),
                  mime_type: mime_type,
                  file_name: file_name(watch_list, language),
                )
              ]
            )
          end

          def serialize_stored_filter(stored_filter, language)
            contents = stored_filter.apply
            pagination_contents = contents.page(1).per(contents.count)
            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [
                DataCycleCore::Serialize::SerializedData::Content.new(
                  data:
                    DataCycleCore::Api::V3::ContentsController.renderer.new(
                      http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
                      https: Rails.application.config.force_ssl
                    ).render(
                      assigns: { contents: pagination_contents, language: language, include_parameters: [], mode_parameters: [], api_version: 3 },
                      template: 'data_cycle_core/api/v3/contents/index',
                      layout: false
                    ),
                  mime_type: mime_type,
                  file_name: file_name(stored_filter, language),
                )
              ]
            )
          end
        end
      end
    end
  end
end
