# frozen_string_literal: true

module DataCycleCore
  module Serialize
    module SerializedData
      class Content
        attr_reader :remote_file_loaded, :data, :file_name, :id, :is_remote, :data_url

        def initialize(data:, mime_type:, file_name:, id:, is_remote: false, data_url: nil)
          @data = data
          @mime_type = mime_type
          @file_name = file_name
          @is_remote = is_remote
          @id = id
          @data_url = data_url
          @remote_file_loaded = false
        end

        def parsed_data_uri
          return if data_url.blank?

          uri = Addressable::URI.parse(data_url)
          uri.hostname = 'nginx' if Rails.env.development? && uri.hostname == Rails.configuration.action_mailer&.default_url_options&.dig(:host)
          uri
        rescue URI::InvalidURIError
          nil
        end

        def faraday_connection
          Faraday.new do |con|
            con.request :retry, { max: 2 }
            con.use FaradayMiddleware::FollowRedirects, limit: 5
            con.adapter Faraday.default_adapter
            con.ssl.verify = false
          end
        end

        def mime_type
          return @mime_type if @mime_type.present?

          return unless remote? && data_url.present?

          response = faraday_connection.head(parsed_data_uri)
          @mime_type = response.headers&.dig('content-type')
        end

        def file_extension
          ext = MiniMime.lookup_by_content_type(mime_type.to_s)&.extension
          return if ext.blank?

          ".#{ext}"
        end

        def file_name_with_extension
          "#{file_name}#{file_extension}"
        end

        # @deprecated: used with carrierwave
        def local_file?
          false
        end

        def active_storage?
          return false if remote? || @data.is_a?(::String)
          record_for_active_storage_file&.file&.try(:attached?)
        end

        def active_storage_file_path
          record_for_active_storage_file.file.service.path_for(data.key)
        end

        # used for remote files and image proxy
        def remote?
          is_remote
        end

        def enumerator?
          @data.is_a?(Enumerator)
        end

        def record_for_active_storage_file
          return data&.blob&.attachments&.first&.record if data.is_a?(ActiveStorage::VariantWithRecord)
          data.try(:record)
        end

        def stream_data(&)
          if local_file?
            yield(data&.read)
          elsif active_storage?
            data&.blob&.download(&)
          elsif remote?
            load_remote_file(&)
          elsif data.is_a?(Proc)
            yield(data.call)
          elsif enumerator?
            @data.each(&)
          else
            yield(data)
          end
        end

        def each_data
          Enumerator.new do |yielder|
            stream_data do |chunk|
              yielder << chunk
            end
          end
        end

        def load_remote_file
          return unless remote? && data_url.present?
          return if remote_file_loaded

          @remote_file_loaded = true
          @data = +''

          response = faraday_connection.get(parsed_data_uri) do |req|
            req.options.on_data = lambda { |chunk, _|
              @data << chunk
              yield(chunk)
            }
          end

          @mime_type = response.headers&.dig('content-type')
        end
      end
    end
  end
end
