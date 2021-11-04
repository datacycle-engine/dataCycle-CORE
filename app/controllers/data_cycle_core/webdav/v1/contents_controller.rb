# frozen_string_literal: true

module DataCycleCore
  module Webdav
    module V1
      class ContentsController < ::DataCycleCore::Webdav::V1::WebdavBaseController
        include DataCycleCore::WebdavHelper
        PUMA_MAX_TIMEOUT = 600

        def index
          props = parse_request(request.body)
          debug(request.body)

          puma_max_timeout = (ENV['PUMA_MAX_TIMEOUT']&.to_i || PUMA_MAX_TIMEOUT) - 1
          Timeout.timeout(puma_max_timeout, DataCycleCore::Error::Api::TimeOutError, "Timeout Error for API Request: #{@_request.fullpath}") do
            @contents = DataCycleCore::StoredFilter.find(permitted_params.dig(:id))

            # builder = Nokogiri::XML::Builder.new do |xml|
            #   xml['d'].multistatus('xmlns:d' => 'DAV:') do
            #     xml['d'].response do
            #       xml['d'].href '/webdav/v1/endpoints/2ae4d149-430b-4cae-9d3a-14d28e85056c/things'
            #       xml['d'].propstat do
            #         xml['d'].prop do
            #           xml['d'].getlastmodified 'Wed, 27 Oct 2021 12:20:17 GMT'
            #           xml['d'].resourcetype do
            #             xml['d'].collection
            #           end
            #           xml['d'].send('quota-used-bytes', '40038')
            #           xml['d'].send('quota-used-bytes', '1050873428')
            #         end
            #         xml['d'].status 'HTTP/1.1 200 OK'
            #       end
            #     end
            #     xml['d'].response do
            #       xml['d'].href '/webdav/v1/endpoints/2ae4d149-430b-4cae-9d3a-14d28e85056c/things/item.md'
            #       xml['d'].propstat do
            #         xml['d'].prop do
            #           xml['d'].getlastmodified 'Wed, 27 Oct 2021 12:20:17 GMT'
            #           xml['d'].getcontentlength '1095'
            #           xml['d'].resourcetype
            #           xml['d'].contenttype 'test/markdown'
            #         end
            #         xml['d'].status 'HTTP/1.1 200 OK'
            #       end
            #     end
            #   end
            # end

            # puts "\n\n"
            # puts builder.to_xml(indent: 2)
            # puts "\n\n"

            render 'index', status: :multi_status
          end
        end

        def show
          ap params
          debug(request.body)
        end

        def options
          debug(request.body)
          response.headers['Allow'] = 'OPTIONS,PROPFIND,GET'
          response.headers['MS-Author-Via'] = 'DAV'
          response.headers['DAV'] = '1,2'
          render xml: 'test', layout: false, status: :ok
        end

        private

        def debug(body, message = 'Request Body')
          puts "\n\n"
          puts message
          puts Nokogiri::XML(body).to_xml(indent: 2)
          puts "\n\n"
        end
      end
    end
  end
end
