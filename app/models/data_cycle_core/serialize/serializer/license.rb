# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module Serializer
      class License < Base
        class << self
          def translatable?
            true
          end

          def mime_type
            'text/plain'
          end

          def serialize_thing(content:, language:, **_options)
            content = content.is_a?(Array) ? content : [content]
            DataCycleCore::Serialize::SerializedData::ContentCollection.new(
              [
                copyright_notice(content, language),
                common_text_bla(language)
              ]
            )
          end

          private

          def copyright_notice(content, language)
            data = []
            content.each do |item|
              data << (item.try(:computed_attribution_name).presence || "#{item.id} - #{item.name}")
            end
            DataCycleCore::Serialize::SerializedData::Content.new(
              data: data.join("\r\n"),
              mime_type: mime_type,
              file_name: "enter_copyright_file_name-here_#{language}",
              id: SecureRandom.uuid
            )
          end

          def common_text_bla(language)
            DataCycleCore::Serialize::SerializedData::Content.new(
              data: "some random text goes here\r\nblaaaaaaaaaaaaaaaaaaaaaaaaaa - language: #{language}",
              mime_type: mime_type,
              file_name: "enter_file_name#{language}",
              id: SecureRandom.uuid
            )
          end
        end
      end
    end
  end
end
