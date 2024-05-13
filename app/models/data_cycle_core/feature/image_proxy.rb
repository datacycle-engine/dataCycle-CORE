# frozen_string_literal: true

require 'openssl'
require 'base64'

module DataCycleCore
  module Feature
    class ImageProxy < Base
      class << self
        SUPPORTED_CONTENT_TYPES = ['Bild', 'ImageObject', 'ImageVariant', 'ImageObjectVariant', 'VideoObject', 'Video', 'PDF'].freeze
        SUPPORTED_FILE_EXTENSIONS = ['jpg', 'jpeg', 'png', 'avif', 'webp', 'gif'].freeze

        def data_hash_module
          DataCycleCore::Feature::DataHash::ImageProxy
        end

        def mini_thumb_url(content:)
          process_image(
            content:,
            variant: 'dynamic',
            image_processing: {
              'preset' => 'default',
              'resize_type' => 'fill',
              'width' => 50,
              'height' => 50,
              'enlarge' => 0,
              'gravity' => 'sm'
            }
          )
        end

        def process_image(content:, variant:, image_processing: {})
          return unless processable?(content:, variant:)

          image_processing = image_processing.presence || config.dig(variant, 'processing')
          target_url = [
            Rails.application.config.asset_host,
            'asset',
            content.id
          ]

          format = image_file_extension(content, variant, image_processing)
          target_url << imgproxy_signature(content, image_processing, format) if image_processing.is_a?(::Hash) && !image_processing.empty?

          target_url << content.cache_valid_since.to_i

          if variant == 'dynamic'
            return unless image_processing.is_a?(::Hash) && !image_processing.empty?
            preset = image_processing.dig('preset') || 'default'
            target_url += [
              preset,
              image_processing.dig('resize_type'),
              image_processing.dig('width'),
              image_processing.dig('height'),
              image_processing.dig('enlarge'),
              image_processing.dig('gravity')
            ]
          else
            target_url << variant
          end

          target_url << image_filename(content, variant, image_processing)
          target_url.join('/')
        end

        def config
          DataCycleCore.features.dig(name.demodulize.underscore.to_sym).dig(:config)
        end

        def frontend_enabled?
          enabled? && DataCycleCore.features.dig(name.demodulize.underscore.to_sym).dig(:frontend, :enabled)
        end

        def supported_content_type?(content)
          SUPPORTED_CONTENT_TYPES.include?(content.template_name)
        end

        private

        def processable?(content:, variant:)
          enabled? && content.is_a?(DataCycleCore::Thing) && supported_content_type?(content) && config.include?(variant) && (content&.asset.present? || content.try(:content_url).present?)
        end

        def image_filename(content, variant, processing)
          name = content.name&.parameterize(separator: '_').presence || content.slug.presence || content.id
          file_extension = image_file_extension(content, variant, processing)
          file_extension.present? ? "#{name}.#{file_extension}" : name
        end

        def image_file_extension(content, variant, processing)
          if processing&.dig('format').present?
            ext_name = processing.dig('format')
          elsif ['default', 'original'].include?(variant)
            orig_url = content.content_url
            ext_name = orig_url.present? ? File.extname(orig_url)&.split('.')&.last : ''
          end
          return if ext_name.blank?
          return 'jpeg' unless SUPPORTED_FILE_EXTENSIONS.include?(ext_name)
          ext_name
        end

        def imgproxy_signature(content, processing, format)
          raise 'Insufficient imgproxy credentials! Validate imgproxy_key and imgproxy_salt secrets!' unless Rails.application.secrets.imgproxy_key.present? && Rails.application.secrets.imgproxy_salt.present?

          key = [Rails.application.secrets.imgproxy_key].pack('H*')
          salt = [Rails.application.secrets.imgproxy_salt].pack('H*')

          application_url = Addressable::URI.parse(Rails.application.config.asset_host)

          url = [
            application_url.to_s,
            'things',
            content.id,
            'asset',
            'content'
          ].join('/')

          cachebuster = content.cache_valid_since.to_i
          preset = processing.dig('preset') || 'default'
          resize_type = processing.dig('resize_type')
          width = processing.dig('width')
          height = processing.dig('height')
          gravity = processing.dig('gravity')
          enlarge = processing.dig('enlarge')
          extension = processing.dig('format') || format

          path = "/cachebuster:#{cachebuster}/preset:#{preset}/resize:#{resize_type}:#{width}:#{height}:#{enlarge}/gravity:#{gravity}/filename:#{content.id}/plain/#{url}@#{extension}"

          digest = OpenSSL::Digest.new('sha256')
          hmac = Base64.urlsafe_encode64(OpenSSL::HMAC.digest(digest, key, "#{salt}#{path}")).tr('=', '')
          hmac
        end
      end
    end
  end
end
