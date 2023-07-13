# frozen_string_literal: true

require 'zip_tricks'

module DataCycleCore
  module Serialize
    module Serializer
      class ContentScore < Base
        class << self
          def translatable?
            true
          end

          def mime_type
            'application/zip'
          end

          def serialize_thing(content:, language:, user:, **_options)
            content = content.is_a?(Array) ? content.first : content

            serialize_contents(
              content: content,
              contents: DataCycleCore::Thing.where(id: content.id),
              language: language,
              user: user
            )
          end

          def serialize_watch_list(content:, language:, user:, **_options)
            watch_list = content.is_a?(Array) ? content.first : content

            serialize_contents(
              content: watch_list,
              contents: watch_list.things,
              language: language,
              user: user
            )
          end

          def serialize_stored_filter(content:, language:, user:, **_options)
            stored_filter = content.is_a?(Array) ? content.first : content

            serialize_contents(
              content: stored_filter,
              contents: stored_filter.apply.query,
              language: language,
              user: user
            )
          end

          def serialize_contents(user:, contents:, content:, language:)
            data = Enumerator.new do |yielder|
              writer = ZipTricks::BlockWrite.new(&yielder)

              ZipTricks::Streamer.open(writer) do |zip|
                output_xlsx = nil

                txt_writer = zip.write_stored_file('contents.csv')
                txt_write = CSV(txt_writer)
                txt_write << ['ID', 'Name', 'URL']

                output_xlsx = DataCycleCore::ApplicationController.renderer_with_user(
                  user,
                  http_host: Rails.application.config.action_mailer.default_url_options.dig(:host),
                  https: Rails.application.config.force_ssl
                ).render(
                  handlers: [:axlsx],
                  formats: [:xlsx],
                  layout: false,
                  locals: { :@contents => contents, :@txt_write => txt_write },
                  template: 'data_cycle_core/contents/content_score'
                )

                txt_write.close

                if output_xlsx
                  zip.write_deflated_file('content_scores.xlsx') do |file_writer|
                    file_writer << output_xlsx
                  end
                end
              end
            end

            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [DataCycleCore::Serialize::SerializedData::Content.new(
                data: data,
                mime_type: mime_type,
                file_name: file_name(content: content, language: language),
                id: content.id
              )]
            )
          end
        end
      end
    end
  end
end
