# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      class Endpoint
        def initialize(host: nil, end_point: nil, token: nil, **options)
          @host = host
          @end_point = end_point
          @token = token
          @retry_options = {
            max: 5,
            interval: 1,
            interval_randomness: 0.5,
            backoff_factor: 2,
            exceptions: [Errno::ETIMEDOUT, Timeout::Error, Faraday::TimeoutError, Faraday::ConnectionFailed, Net::OpenTimeout]
          }
        end

        def media_assets(lang: :de)
          Enumerator.new do |yielder|
            load_folders.xpath('//folder/id').map(&:text).map(&:to_i).sort.reverse_each do |folder_id|
              doc = load_assets(folder_id)
              doc.xpath('//mediaasset').map(&:to_hash).each do |raw_asset_data|
                next if raw_asset_data['mediaassettype']['text'] != '501'

                raise 'Missing image file' if raw_asset_data.dig('quality_1').blank?
                full_image_path = File.join(Rails.public_path, 'eyebase', 'media_assets', 'files', raw_asset_data.dig('quality_1', 'filename', 'text'))
                load_file(full_image_path, raw_asset_data.dig('quality_1', 'url', '#cdata-section')) unless File.file?(full_image_path)

                raise 'Missing thumbnail file' if raw_asset_data.dig('quality_512').blank?
                thumbnail_path = File.join(Rails.public_path, 'eyebase', 'media_assets', 'files', raw_asset_data.dig('quality_512', 'filename', 'text'))
                load_file(thumbnail_path, raw_asset_data.dig('quality_512', 'url', '#cdata-section')) unless File.file?(thumbnail_path)

                yielder << raw_asset_data
              end
            end
          end
        end

        protected

        def load_folders
          load(qt: 'ftree')
        end

        def load_assets(folder_id)
          load(qt: 'r', keyfolder: folder_id)
        end

        def load(**parameters)
          conn = Faraday::Connection.new(File.join([@host, @end_point])) do |f|
            f.request :retry, @retry_options
            f.adapter Faraday.default_adapter
          end

          response = conn.get do |req|
            req.params['fx'] = 'api'
            req.params['token'] = @token
            req.params['qt'] = parameters.dig(:qt) if parameters.dig(:qt).present?
            req.params['keyfolder'] = parameters.dig(:keyfolder) if parameters.dig(:keyfolder).present?
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from url: #{File.join([@host, @end_point])}, params: token=#{@token}, qt=#{parameters.dig(:qt)}, keyfolder=#{parameters.dig(:keyfolder)}", response) unless response.success?
          Nokogiri::XML(response.body)
        end

        def load_file(dest, source)
          conn = Faraday.new(source) do |f|
            f.request :retry, @retry_options
            f.adapter Faraday.default_adapter
          end
          response = conn.get

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from url: #{source}", response) unless response.success?

          FileUtils.mkdir_p(File.dirname(dest))
          File.open(dest, 'wb') do |local_file|
            local_file.write(response.body)
          end
        end
      end
    end
  end
end
