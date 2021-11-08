# frozen_string_literal: true

module DataCycleCore
  module Webdav
    module V1
      class ContentsController < ::DataCycleCore::Webdav::V1::WebdavBaseController
        PUMA_MAX_TIMEOUT = 600

        def index
          @props = parse_request(request.body)
          @header = parse_header(request) # depth setting in Header

          # puts 'Header:'
          # puts @header
          # debug(request.body)

          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1
          Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
            @contents = DataCycleCore::StoredFilter.find(permitted_params.dig(:id))

            render 'index', status: :multi_status
          end
        end

        def show
          @props = parse_request(request.body)
          @header = parse_header(request)
          @id = permitted_params.dig(:id)
          @content = DataCycleCore::StoredFilter.find(@id).apply.where(slug: permitted_params.dig(:file_name))&.first

          render 'show', status: :multi_status
        end

        def download
          @props = parse_request(request.body)
          @header = parse_header(request)
          @content = DataCycleCore::StoredFilter.find(permitted_params.dig(:id)).apply.where(slug: permitted_params.dig(:file_name))&.first

          # ap params
          # puts 'Header:'
          # puts @header
          # debug(request.body)

          if @content.assets.blank?
            send_data generate_file(@content), disposition: 'inline', filename: [@content.name, '.txt'].join, type: 'text/plain'
            return
          end

          @asset = @content.assets.first.file
          @asset_path = @asset.file.file

          headers['ETag'] = %("#{File.mtime(@asset_path)}-#{@asset.try(:size)}")
          headers['Last-Modified'] = File.mtime(@asset_path).httpdate
          headers['Content-Length'] = @content.assets.first&.file&.size
          headers['Content-Type'] = @content.assets.first&.content_type
          headers['Displayname'] = @asset.file_name
          headers['Display-Name'] = @asset.file_name
          headers.delete 'X-Frame-Options'

          send_file @asset_path, disposition: 'inline', filename: @asset.file_name, type: @asset.content_type
        end

        def options
          response.headers['Allow'] = 'OPTIONS,PROPFIND,GET'
          response.headers['MS-Author-Via'] = 'DAV'
          response.headers['DAV'] = '1'

          render xml: 'test', layout: false, status: :ok
        end

        private

        def debug(body, message = 'Request Body')
          # puts "\n\n"
          # puts message
          # puts Nokogiri::XML(body).to_xml(indent: 2)
          # puts "\n\n"
        end
      end
    end
  end
end
