# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module Serializer
      class Indesign < Base
        class << self
          def translatable?
            true
          end

          def mime_type
            'application/xml'
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
            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [
                DataCycleCore::Serialize::SerializedData::Content.new(
                  data: lambda {
                    Nokogiri::XML(
                      DataCycleCore::Xml::V1::WatchListsController.renderer.new(
                        http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
                        https: Rails.application.config.force_ssl
                      ).render(
                        assigns: { watch_list:, language:, include_parameters: ['linked'], mode_parameters: ['indesign'], api_version: 1, api_context: 'xml' },
                        template: 'data_cycle_core/xml/v1/watch_lists/show',
                        layout: false
                      ),
                      &:noblanks
                    )&.to_xml
                  },
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
                  data: lambda {
                    Nokogiri::XML(
                      DataCycleCore::Xml::V1::ContentsController.renderer.new(
                        http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
                        https: Rails.application.config.force_ssl
                      ).render(
                        assigns: { contents: pagination_contents, language:, include_parameters: ['linked'], mode_parameters: ['indesign'], api_version: 1, api_context: 'xml' },
                        template: 'data_cycle_core/xml/v1/contents/index',
                        layout: false
                      ),
                      &:noblanks
                    )&.to_xml
                  },
                  mime_type:,
                  file_name: file_name(content: stored_filter, language:),
                  id: stored_filter.id
                )
              ]
            )
          end

          def serializable?(content)
            DataCycleCore::Feature::Serialize.available_serializer?(content, name.demodulize.underscore) && content.asset_property_names.blank?
          end

          private

          def serialize(content, language)
            DataCycleCore::Serialize::SerializedData::Content.new(
              data: lambda {
                Nokogiri::XML(
                  DataCycleCore::Xml::V1::ContentsController.renderer.new(
                    http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
                    https: Rails.application.config.force_ssl
                  ).render(
                    assigns: { content:, language:, include_parameters: ['linked'], mode_parameters: ['indesign'], api_version: 1, api_context: 'xml' },
                    template: 'data_cycle_core/xml/v1/contents/show',
                    layout: false
                  ),
                  &:noblanks
                )&.to_xml
              },
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
