# frozen_string_literal: true

require 'openssl'
require 'base64'

module DataCycleCore
  module Utility
    module Virtual
      module Asset
        class << self
          def proxy_url(**args)
            transformations = args.dig(:virtual_definition, 'virtual', 'transformation')
            name = args.dig(:content).name&.parameterize(separator: '_') || args.dig(:content).id
            if transformations.dig('version') == 'original'
              content = args.dig(:content)
              if content.respond_to?(:asset) && content.send(:asset).present?
                orig_url = content.send(:asset)&.try(:file)&.try(:url)
              else
                orig_url = content.content_url
              end
              [
                Rails.application.config.asset_host,
                'asset',
                args.dig(:content).id,
                transformations.dig('version'),
                "#{name}#{orig_url.present? ? File.extname(orig_url) : ''}"
              ].join('/')
            elsif transformations.dig('version') == 'dynamic'
              [
                Rails.application.config.asset_host,
                'asset',
                args.dig(:content).id,
                transformations.dig('type'),
                transformations.dig('width'),
                transformations.dig('height'),
                "#{name}.#{transformations.dig('format')}"
              ].join('/')
            else
              [
                Rails.application.config.asset_host,
                'asset',
                args.dig(:content).id,
                transformations.dig('version'),
                "#{name}.#{transformations.dig('format')}"
              ].join('/')
            end
          end

          def imgproxy(**args)
            transformations = args.dig(:virtual_definition, 'virtual', 'transformation')
            image_processing = args.dig(:virtual_definition, 'virtual', 'processing')

            name = args.dig(:content).name&.parameterize(separator: '_') || args.dig(:content).id

            if image_processing&.dig('format').present?
              file_extension = ".#{image_processing.dig('format')}"
            else
              content = args.dig(:content)
              if content.respond_to?(:asset) && content.send(:asset).present?
                orig_url = content.send(:asset)&.try(:file)&.try(:url)
              else
                orig_url = content.content_url
              end
              file_extension = orig_url.present? ? File.extname(orig_url) : ''
            end

            target_url = [
              Rails.application.config.asset_host,
              'asset',
              args.dig(:content).id
            ]

            target_url << imgproxy_signature(args.dig(:content).id, args.dig(:virtual_definition, 'virtual', 'processing')) if image_processing.present? && image_processing.is_a?(::Hash)

            if transformations.dig('version') == 'dynamic'
              target_url += [
                image_processing.dig('resize_type'),
                image_processing.dig('width'),
                image_processing.dig('height'),
                image_processing.dig('enlarge'),
                image_processing.dig('gravity')
              ]
            else
              target_url << transformations.dig('version')
            end

            target_url << "#{name}#{file_extension}"

            target_url.join('/')
          end

          def imgproxy_signature(content_id, processing)
            raise 'Insufficient imgproxy credentials! Validate imgproxy_key and imgproxy_salt secrets!' unless Rails.application.secrets.imgproxy_key.present? && Rails.application.secrets.imgproxy_salt.present?

            key = [Rails.application.secrets.imgproxy_key].pack('H*')
            salt = [Rails.application.secrets.imgproxy_salt].pack('H*')

            application_url = Rails.application.config.asset_host
            application_url = "http://nginx:#{ENV.fetch('PUBLIC_APPLICATION_PORT')}" if Rails.env.development?

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
end
