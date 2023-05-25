# frozen_string_literal: true

require 'pdfkit'

module DataCycleCore
  module Serialize
    module Serializer
      class Pdf < Base
        class << self
          def translatable?
            true
          end

          def mime_type
            'application/pdf'
          end

          def serialize_thing(content:, language:, user:, **_options)
            content = Array.wrap(content).first

            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [
                DataCycleCore::Serialize::SerializedData::Content.new(
                  data: PDFKit.new(
                    I18n.with_locale(language) do
                      DataCycleCore::ApplicationController.renderer_with_user(
                        user,
                        http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
                        https: Rails.application.config.force_ssl
                      ).render_to_string(
                        formats: [:html],
                        layout: 'data_cycle_core/pdf',
                        locals: { :@content => content },
                        template: 'data_cycle_core/pdf/contents/show'
                      ).squish
                    end,
                    root_url: Rails.application.config.action_mailer.default_url_options.dig(:host),
                    protocol: Rails.application.config.force_ssl ? 'https' : 'http'
                  ).to_pdf,
                  mime_type: mime_type,
                  file_name: file_name(content: content, language: language),
                  id: content.id
                )
              ]
            )
          end

          def serialize_watch_list(**_options)
            raise 'NOT IMPLEMENTED!'
          end

          def serialize_stored_filter(**_options)
            raise 'NOT IMPLEMENTED!'
          end
        end
      end
    end
  end
end
