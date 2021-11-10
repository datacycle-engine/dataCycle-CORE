# frozen_string_literal: true

require 'openssl'
require 'base64'

module DataCycleCore
  module Feature
    class ImageProxy < Base
      class << self
        def process_image(content:, variant:, image_processing: {})
          return if !content.is_a?(DataCycleCore::Thing) || !config.include?(variant) || !enabled?

          image_processing = image_processing.presence || config.dig(variant, 'processing')

          target_url = [
            Rails.application.config.asset_host,
            'asset',
            content.id
          ]
          target_url << imgproxy_signature(content.id, image_processing) if image_processing.is_a?(::Hash) && !image_processing.empty?

          if variant == 'dynamic'
            target_url += [
              image_processing.dig('resize_type'),
              image_processing.dig('width'),
              image_processing.dig('height'),
              image_processing.dig('enlarge'),
              image_processing.dig('gravity')
            ]
          else
            target_url << variant
          end

          target_url << image_filename(content, image_processing)
          target_url.join('/')
        end

        def config
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym).dig(:config)
        end

        private

        def image_filename(content, processing)
          name = content.name&.parameterize(separator: '_') || content.id
          file_extension = image_file_extension(content, processing)
          "#{name}#{file_extension}"
        end

        def image_file_extension(content, processing)
          if processing&.dig('format').present?
            ".#{processing.dig('format')}"
          else
            if content.respond_to?(:asset) && content.send(:asset).present?
              orig_url = content.send(:asset)&.try(:file)&.try(:url)
            else
              orig_url = content.content_url
            end
            orig_url.present? ? File.extname(orig_url) : ''
          end
        end

        def imgproxy_signature(content_id, processing)
          raise 'Insufficient imgproxy credentials! Validate imgproxy_key and imgproxy_salt secrets!' unless Rails.application.secrets.imgproxy_key.present? && Rails.application.secrets.imgproxy_salt.present?

          key = [Rails.application.secrets.imgproxy_key].pack('H*')
          salt = [Rails.application.secrets.imgproxy_salt].pack('H*')

          application_url = Rails.application.config.asset_host
          application_url = "http://nginx:#{ENV.fetch('PUBLIC_APPLICATION_PORT')}" if ENV.fetch('APP_DOCKER_ENV') { nil }.present?

          url = [
            application_url,
            'things',
            content_id,
            'asset',
            'content'
          ].join('/')

          resize_type = processing.dig('resize_type')
          width = processing.dig('width')
          height = processing.dig('height')
          gravity = processing.dig('gravity')
          enlarge = processing.dig('enlarge')
          extension = processing.dig('format')

          path = "/resize:#{resize_type}:#{width}:#{height}:#{enlarge}/gravity:#{gravity}/filename:#{content_id}/plain/#{url}@#{extension}"

          digest = OpenSSL::Digest.new('sha256')
          hmac = Base64.urlsafe_encode64(OpenSSL::HMAC.digest(digest, key, "#{salt}#{path}")).tr('=', '')
          hmac
        end
      end
    end
  end
end
