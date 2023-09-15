# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module Serializer
      class Json < Base
        class << self
          def translatable?
            true
          end

          def mime_type
            'application/json'
          end

          def serialize_thing(content:, language:, **_options)
            content = [content] unless content.is_a?(Array)
            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              content
                .select { |item| serializable?(item) }
                .map { |item| serialize(item, language) }
            )
          end

          def serialize_watch_list(content:, language:, **_options)
            watch_list = content.is_a?(Array) ? content.first : content
            query = DataCycleCore::Thing.joins(:watch_list_data_hashes).where(watch_list_data_hashes: { watch_list_id: watch_list.id }).order('watch_list_data_hashes.order_a ASC, watch_list_data_hashes.created_at ASC, things.id DESC')
            pagination_contents = query.page(1).per(query.count)

            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [
                DataCycleCore::Serialize::SerializedData::Content.new(
                  data:
                    DataCycleCore::Api::V3::WatchListsController.renderer.new(
                      http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
                      https: Rails.application.config.force_ssl
                    ).render(
                      assigns: { contents: pagination_contents, watch_list:, language:, include_parameters: [], mode_parameters: [], api_version: 3, api_context: 'api' },
                      template: 'data_cycle_core/api/v3/watch_lists/show',
                      layout: false
                    ),
                  mime_type:,
                  file_name: file_name(content: watch_list, language:),
                  id: watch_list.id
                )
              ]
            )
          end

          def serialize_stored_filter(content:, language:, **_options)
            stored_filter = content.is_a?(Array) ? content.first : content
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
                      assigns: { contents: pagination_contents, language:, include_parameters: [], mode_parameters: [], api_version: 3, api_context: 'api' },
                      template: 'data_cycle_core/api/v3/contents/index',
                      layout: false
                    ),
                  mime_type:,
                  file_name: file_name(content: stored_filter, language:),
                  id: stored_filter.id
                )
              ]
            )
          end

          private

          def serialize(content, language)
            DataCycleCore::Serialize::SerializedData::Content.new(
              data:
                DataCycleCore::Api::V3::ContentsController.renderer.new(
                  http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
                  https: Rails.application.config.force_ssl
                ).render(
                  assigns: { content:, language:, include_parameters: [], mode_parameters: [], api_version: 3, api_context: 'api' },
                  template: 'data_cycle_core/api/v3/contents/show',
                  layout: false
                ),
              mime_type:,
              file_name: file_name(content:, language:),
              id: content.id
            )
          end
        end
      end
    end
  end
end
