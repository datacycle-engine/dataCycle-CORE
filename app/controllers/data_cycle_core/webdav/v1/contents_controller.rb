# frozen_string_literal: true

module DataCycleCore
  module Webdav
    module V1
      class ContentsController < ::DataCycleCore::Webdav::V1::WebdavBaseController
        PUMA_MAX_TIMEOUT = 600

        after_action :log_activity, except: [:options]
        skip_before_action :authenticate_user!, only: [:options]

        def index
          @props = parse_request(request.body)
          @header = parse_header(request) # depth setting in Header

          # logger.info @header
          # logger.error Nokogiri::XML(request.body).to_xml(indent: 2)
          # puts 'Header:'
          # puts @header
          # debug(request.body)

          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1
          Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
            @collection = load_collection(permitted_params.dig(:id), current_user)
            @contents =
              if @header['DEPTH'] == '0'
                []
              else
                load_contents(@collection)
              end

            render 'index', status: :multi_status
          end
        end

        def show
          @props = parse_request(request.body)
          @header = parse_header(request)
          @id = permitted_params.dig(:id)

          # logger.info @header
          # logger.info Nokogiri::XML(request.body).to_xml(indent: 2)

          @content = load_content(permitted_params.dig(:id), permitted_params.dig(:file_name), current_user)

          raise ActiveRecord::RecordNotFound if @content.blank?
          render 'show', status: :multi_status
        end

        def show_collection
          @props = parse_request(request.body)
          @header = parse_header(request)
          @id = permitted_params.dig(:id)

          # logger.error @header
          # logger.error Nokogiri::XML(request.body).to_xml(indent: 2)

          @collection = load_collection(permitted_params.dig(:id), current_user)
          @contents = []

          render 'index', status: :multi_status
        end

        def download
          @props = parse_request(request.body)
          @header = parse_header(request)
          @content = load_content(permitted_params.dig(:id), permitted_params.dig(:file_name), current_user)

          # ap params
          # puts 'Header:'
          # puts @header
          # debug(request.body)

          if @content.assets.blank?
            send_data generate_file(@content), disposition: 'inline', filename: [@content.name, '.txt'].join, type: 'text/plain'
            return
          end

          @asset = @content.assets.first.file
          if @asset.try(:record)&.class&.active_storage_activated? && @asset.try(:attached?)
            @asset_path = @asset.service.path_for(@asset.key)
            filename = @asset.filename.to_s
            headers['ETag'] = %("#{File.mtime(@asset_path)}-#{@asset.record.file_size}")
            headers['Last-Modified'] = File.mtime(@asset_path).httpdate
            headers['Content-Length'] = @asset.record.file_size
            headers['Content-Type'] = @asset.record.content_type
          else
            @asset_path = @asset.file.file
            filename = @asset.file_name
            headers['ETag'] = %("#{File.mtime(@asset_path)}-#{@asset.try(:size)}")
            headers['Last-Modified'] = File.mtime(@asset_path).httpdate
            headers['Content-Length'] = @content.assets.first&.file&.size
            headers['Content-Type'] = @content.assets.first&.content_type
          end
          headers['Displayname'] = filename
          headers['Display-Name'] = filename

          headers.delete 'X-Frame-Options'
          send_file @asset_path, disposition: 'inline', filename: filename, type: @asset.content_type
        end

        def options
          response.headers['Allow'] = 'OPTIONS,PROPFIND,GET'
          response.headers['MS-Author-Via'] = 'DAV'
          response.headers['DAV'] = '1'

          render xml: '', layout: false, status: :ok
        end

        private

        def load_collection(id, user)
          watch_list = DataCycleCore::WatchList.find(id)
          raise ActiveRecord::RecordNotFound if watch_list.blank? || watch_list.user_id != user.id
          watch_list
        end

        def load_contents(collection)
          collection.things
        end

        def load_content(id, file_name, user)
          load_contents(load_collection(id, user)).where(slug: file_name)&.first
        end

        # def debug(body, message = 'Request Body')
        #   puts "\n\n"
        #   puts message
        #   puts Nokogiri::XML(body).to_xml(indent: 2)
        #   puts "\n\n"
        # end
      end
    end
  end
end
