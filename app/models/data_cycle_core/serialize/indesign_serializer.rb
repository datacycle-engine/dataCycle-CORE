# frozen_string_literal: true

module DataCycleCore
  module Serialize
    class IndesignSerializer
      class << self
        def translatable?
          true
        end

        def mime_type(_serialized_content, _content)
          'application/xml'
        end

        def file_extension(_mime_type)
          '.xml'
        end

        def serialize(content, language, _version, _transformation = nil)
          Nokogiri::XML(
            DataCycleCore::Xml::V1::ContentsController.renderer.new(
              http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
              https: Rails.application.config.force_ssl
            ).render(
              assigns: { content: content, language: language, include_parameters: ['linked'], mode_parameters: ['indesign'] },
              template: 'data_cycle_core/xml/v1/contents/show',
              layout: false
            ),
            &:noblanks
          )&.to_xml
        end

        def serialize_watch_list(watch_list, language, _version, _transformation = nil)
          Nokogiri::XML(
            DataCycleCore::Xml::V1::WatchListsController.renderer.new(
              http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
              https: Rails.application.config.force_ssl
            ).render(
              assigns: { watch_list: watch_list, language: language, include_parameters: ['linked'], mode_parameters: ['indesign'] },
              template: 'data_cycle_core/xml/v1/watch_lists/show',
              layout: false
            ),
            &:noblanks
          )&.to_xml
        end

        def serialize_stored_filter(stored_filter, language, _version, _transformation = nil)
          contents = stored_filter.apply
          pagination_contents = contents.page(1).per(contents.count)
          Nokogiri::XML(
            DataCycleCore::Xml::V1::ContentsController.renderer.new(
              http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
              https: Rails.application.config.force_ssl
            ).render(
              assigns: { contents: pagination_contents, language: language, include_parameters: ['linked'], mode_parameters: ['indesign'] },
              template: 'data_cycle_core/xml/v1/contents/index',
              layout: false
            ),
            &:noblanks
          )&.to_xml
        end
      end
    end
  end
end