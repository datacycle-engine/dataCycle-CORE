# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      class Endpoint
        def initialize(host: nil, end_point: nil, token: nil, **options)
          @host = host
          @end_point = end_point
          @token = token
          @options = options[:options] || {}
          @params = @options[:params] || {}
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
            load(qt: 'ftree').xpath('//folder').map { |folder|
              {
                folder.search('./id/text()').text.to_i =>
                ([folder] + folder.ancestors('folder')).map { |n| n.search('./name/text()').text }.reverse
              }
            }.reduce({}, :merge).each do |folder_id, path|
              doc = load_assets(folder_id)
              doc.xpath('//mediaasset').map(&:to_hash).each do |raw_asset_data|
                next if raw_asset_data.dig('mediaassettype', 'text') != '501'
                next if raw_asset_data.dig('main_permalink', '#cdata-section').blank?
                next if raw_asset_data.dig('quality_512', 'permalink', '#cdata-section').blank?

                raw_asset_data['full_path'] = path

                path_nodes = ([nil] + path).zip(path).map { |parent, folder| { parent: parent, folder: folder } if folder.present? }.compact
                path_nodes = path_nodes.zip(0..path.size).map { |data, i| data.merge({ path: path[0..i].join(', '), parent_path: path[0...i].join(', ').presence }) }
                raw_asset_data['folder'] = path_nodes

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
          changed_from = @params[:changed_from]
          load(qt: 'r', keyfolder: folder_id, changed_from: changed_from)
        end

        def load(**parameters)
          changed_from = parameters.dig(:changed_from)
          conn = Faraday::Connection.new(File.join([@host, @end_point])) do |f|
            f.request :retry, @retry_options
            f.response :logger
            f.adapter Faraday.default_adapter
          end

          response = conn.get do |req|
            req.headers['cookie'] = @cookie_values.map { |k, v| "#{k}=#{v}" }.join('; ') if @cookie_values.present?

            req.params['fx'] = 'api'
            req.params['token'] = @token
            req.params['qt'] = parameters.dig(:qt) if parameters.dig(:qt).present?
            req.params['keyfolder'] = parameters.dig(:keyfolder) if parameters.dig(:keyfolder).present?
            if changed_from.present?
              req.params['column_1'] = 'geaendert'
              req.params['operator_1'] = 3
              req.params['choice_1'] = changed_from.beginning_of_day.to_s
            end
          end

          @cookie_values = (@cookie_values || {}).merge(Hash[
            response.headers['set-cookie']
                    .split(/[;,]/)
                    .map(&:strip)
                    .map { |c| c.split('=') }
          ].select { |k, _| ['PHPSESSID', 'apiax', 'apism', 'apixi'].include?(k) })

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from url: #{File.join([@host, @end_point])}, params: token=#{@token}, qt=#{parameters.dig(:qt)}, keyfolder=#{parameters.dig(:keyfolder)}", response) unless response.success?
          Nokogiri::XML(response.body)
        end
      end
    end
  end
end
