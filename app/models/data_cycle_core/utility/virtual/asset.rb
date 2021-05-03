# frozen_string_literal: true
require "openssl"
require "base64"

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
                imgproxy_signature(args.dig(:content).id, args.dig(:virtual_definition, 'virtual', 'processing')),
                'orig',
                "#{name}#{orig_url.present? ? File.extname(orig_url) : ''}"
              ].join('/')
            elsif transformations.dig('version') == 'dynamic'
              [
                Rails.application.config.asset_host,
                'asset',
                args.dig(:content).id,
                imgproxy_signature(args.dig(:content).id, args.dig(:virtual_definition, 'virtual', 'processing')),
                image_processing.dig('resize_type'),
                image_processing.dig('width'),
                image_processing.dig('height'),
                image_processing.dig('enlarge'),
                image_processing.dig('gravity'),
                "#{name}.#{image_processing.dig('format')}"
              ].join('/')
            else
              [
                Rails.application.config.asset_host,
                'asset',
                args.dig(:content).id,
                imgproxy_signature(args.dig(:content).id, args.dig(:virtual_definition, 'virtual', 'processing')),
                transformations.dig('version'),
                "#{name}.#{image_processing.dig('format')}"
              ].join('/')
            end
          end

          def imgproxy_signature(content_id, processing)
            key = [Rails.application.secrets.imgproxy_key].pack("H*")
            salt = [Rails.application.secrets.imgproxy_salt].pack("H*")
            url = [
              Rails.application.config.asset_host,
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

            digest = OpenSSL::Digest.new("sha256")
            hmac = Base64.urlsafe_encode64(OpenSSL::HMAC.digest(digest, key, "#{salt}#{path}")).tr("=", "")
            hmac
            # signed_path = "/#{hmac}#{path}"
            # "/resize:fit:0:0:0/gravity:ce/filename:2ba622ac-cfc5-4e23-953f-2bc3e22c5d47/plain/http://localhost:3007/things/2ba622ac-cfc5-4e23-953f-2bc3e22c5d47/asset/content@jpeg"
            # "/resize:fit:0:0:0/gravity:ce/filename:2ba622ac-cfc5-4e23-953f-2bc3e22c5d47/plain/http://localhost:3007/things/2ba622ac-cfc5-4e23-953f-2bc3e22c5d47/asset/content@jpg
            # "/resize:fit:0:0:0/gravity:ce/filename:2ba622ac-cfc5-4e23-953f-2bc3e22c5d47/plain/http://localhost:3007/things/2ba622ac-cfc5-4e23-953f-2bc3e22c5d47/asset/content@"
          end

        end

      end
    end
  end
end
