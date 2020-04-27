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
                next if raw_asset_data.dig('mediaassettype', 'text') != '501'
                next if raw_asset_data.dig('main_permalink', '#cdata-section').blank?
                next if raw_asset_data.dig('quality_512', 'permalink', '#cdata-section').blank?
                if raw_asset_data.dig('ordnerstruktur', '#cdata-section').present?
                  path = raw_asset_data.dig('ordnerstruktur', '#cdata-section').split(',')&.map(&:squish)
                  path_nodes = ([nil] + path).zip(path).map { |parent, folder| { parent: parent, folder: folder } if folder.present? }.compact
                  path_nodes = path_nodes.zip(0..path.size).map { |data, i| data.merge({ path: path[0..i].join(', '), parent_path: path[0...i].join(', ').presence }) }
                  raw_asset_data['folder'] = path_nodes
                end
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
            f.response :logger
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
      end
    end
  end
end
