# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Eyebase
      class Endpoint
        def initialize(host: nil, end_point: nil, token: nil, **options)
          @host = host
          @end_point = end_point
          @token = token
          @credentials = { user: options[:user], password: options[:password] }
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

        def faraday
          Faraday::Connection.new(File.join([@host, @end_point])) do |f|
            f.request :retry, @retry_options

            f.response :logger
            f.response :follow_redirects

            f.adapter Faraday.default_adapter
          end
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
                # 501 images
                # 502 documents (pdf, doc ...)
                # 503 video / audio
                next unless raw_asset_data.dig('mediaassettype', 'text').in?(['501', '503'])
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

        def deleted_assets(*)
          Enumerator.new do |yielder|
            load_deleted_assets.xpath('//item').each do |item|
              yielder << item.to_hash.transform_values { |v| v['#cdata-section'] }
            end
          end
        end

        protected

        def login
          perform_request(fx: 'api', qt: 'login', benutzer: @credentials[:user], ben_kennung: @credentials[:password])
        end

        def load_deleted_assets(days = 14)
          login if @cookie_values.blank?

          perform_request(fx: 'api', token: @token, qt: 'xdel', days: days)
        end

        def load_folders
          load(qt: 'ftree')
        end

        def load_assets(folder_id)
          load(qt: 'r', keyfolder: folder_id, changed_from: @params[:changed_from])
        end

        def load(**parameters)
          login if @cookie_values.blank?

          params = {
            fx: 'api',
            token: @token,
            qt: parameters.dig(:qt),
            keyfolder: parameters.dig(:keyfolder),
            column_1: parameters.dig(:changed_from).present? ? 'geaendert' : nil,
            operator_1: parameters.dig(:changed_from).present? ? 3 : nil,
            choice_1: parameters.dig(:changed_from).present? ? parameters.dig(:changed_from).beginning_of_day.to_s : nil
          }.reject { |_, v| v.blank? }

          perform_request(params)
        end

        def perform_request(**params)
          response = faraday.get do |req|
            req.headers['cookie'] = @cookie_values.map { |k, v| "#{k}=#{v}" }.join('; ') if @cookie_values.present?

            params.map { |k, v| req.params[k.to_s] = v }
          end

          @cookie_values = (@cookie_values || {}).merge(
            Hash[
              response.headers['set-cookie'].split(/[;,]/).map { |c| c.strip.split('=') }
            ].select { |k, _| ['clientmode', 'terms', 'PHPSESSID', 'sm', 'xi', 'ax', 'apism', 'apixi', 'apiax'].include?(k) }
          )

          unless response.success?
            raise DataCycleCore::Generic::Common::Error::EndpointError.new(
              "error loading data from url: #{File.join([@host, @end_point])}, params: " +
              params.map { |k, v| "#{k}=#{v}" }.join(', '), ''
            )
          end

          Nokogiri::XML(response.body)
        end
      end
    end
  end
end
