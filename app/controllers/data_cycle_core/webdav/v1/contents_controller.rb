# frozen_string_literal: true

module DataCycleCore
  module Webdav
    module V1
      class ContentsController < ::DataCycleCore::Webdav::V1::WebdavBaseController
        PUMA_MAX_TIMEOUT = 600

        after_action :log_activity, except: [:options]

        def index
          @props = parse_request(request.body)
          @header = parse_header(request) # depth setting in Header

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

          @content = load_content(permitted_params.dig(:id), permitted_params.dig(:file_name), current_user)

          raise ActiveRecord::RecordNotFound if @content.blank?
          render 'show', status: :multi_status
        end

        def show_collection
          @props = parse_request(request.body)
          @header = parse_header(request)
          @id = permitted_params.dig(:id)

          @collection = load_collection(permitted_params.dig(:id), current_user)
          @contents = []

          render 'index', status: :multi_status
        end

        def download
          @props = parse_request(request.body)
          @header = parse_header(request)
          @content = load_content(permitted_params.dig(:id), permitted_params.dig(:file_name), current_user)

          if @content.assets.blank?
            send_data generate_file(@content), disposition: 'inline', filename: [@content.name, '.txt'].join, type: 'text/plain'
            return
          end

          @asset = @content.assets.first.file
          @asset_path = @asset.service.path_for(@asset.key)
          filename = @asset.filename.to_s
          headers['ETag'] = %("#{File.mtime(@asset_path)}-#{@asset.record.file_size}")
          headers['Last-Modified'] = File.mtime(@asset_path).httpdate
          headers['Content-Length'] = @asset.record.file_size
          headers['Content-Type'] = @asset.record.content_type
          headers['Displayname'] = filename
          headers['Display-Name'] = filename

          headers.delete 'X-Frame-Options'
          send_file @asset_path, disposition: 'inline', filename:, type: @asset.content_type
        end

        def options
          response.headers['Allow'] = 'OPTIONS,PROPFIND,GET'
          response.headers['MS-Author-Via'] = 'DAV'
          response.headers['DAV'] = '1'

          render xml: '', layout: false, status: :ok
        end

        private

        def load_collection(id, user)
          DataCycleCore::Collection.accessible_by(user.send(:ability), :index).find(id)
        end

        def load_contents(collection)
          collection.things
        end

        def load_content(id, file_name, user)
          load_contents(load_collection(id, user)).where(slug: file_name)&.first
        end
      end
    end
  end
end
