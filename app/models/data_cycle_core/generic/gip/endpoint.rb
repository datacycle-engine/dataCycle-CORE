# frozen_string_literal: true

module DataCycleCore
  module Generic
    module Gip
      class Endpoint
        def initialize(host: nil, end_point: nil, **options)
          @host = host
          @end_point = end_point
          @read_type = options[:read_type] if options[:read_type].present?
          @max_retry = 5
          @page_size = 20
        end

        def routes(*)
          Enumerator.new do |yielder|
            [1159, 1160, 1161, 1170, 2053, 2054, 2088].each do |cat_number|
              lookup_params = {
                'method' => 'NameSearch',
                'params' => {
                  'nameClass' => 2,
                  'nameCat' => cat_number,
                  'noDatabaseRestriction' => true
                }
              }
              load_object_ids(['gip-service/gipservlet'], lookup_params, 0)['items'].each do |object|
                yielder << load_feature(['gip-service/vipfeatures'], object['value'], 0)
              end
            end
          end
        end

        def measures(*)
          Enumerator.new do |yielder|
            load_routes.each_slice(@page_size) do |objects|
              params = {
                'layers' => ['ANY'],
                'objectIds' => objects
              }
              load_data(['get_measure'], params, 0)['features'].each do |feature|
                yielder << feature
              end
            end
          end
        end

        def routes_at(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'GEONAME_ATROUTE', 0)['items'].each do |route|
              yielder << route
            end
          end
        end

        def routes_euro(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'GEONAME_EUROVELO', 0)['items'].each do |route|
              yielder << route
            end
          end
        end

        def orgcodes(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'ORGCODE', 0)['items'].each do |data|
              yielder << data
            end
          end
        end

        def minortyperefs(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'MINORTYPEREF', 0)['items'].each do |data|
              yielder << data
            end
          end
        end

        def bikeroutes(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'BIKEROUTE', 0)['items'].each do |data|
              yielder << data
            end
          end
        end

        def bikeroutestates(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'BIKEROUTESTATE', 0)['items'].each do |data|
              yielder << data
            end
          end
        end

        def signages(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'SIGNAGE', 0)['items'].each do |data|
              yielder << data
            end
          end
        end

        def bikecomforts(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'BIKECOMFORT', 0)['items'].each do |data|
              yielder << data
            end
          end
        end

        def databases(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'DATABASE', 0)['items'].each do |data|
              yielder << data
            end
          end
        end

        def sustainers(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'SUSTAINER', 0)['items'].each do |data|
              yielder << data
            end
          end
        end

        def regionalcodes(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'REGIONALCODE', 0)['items'].each do |data|
              yielder << data
            end
          end
        end

        def referencetypes(*)
          Enumerator.new do |yielder|
            look_up(['gip-service/gipservlet'], 'REFERENCETYPE', 0)['items'].each do |data|
              yielder << data
            end
          end
        end

        protected

        def look_up(url_path, table, retry_count = 0)
          params = {
            'method' => 'lookup',
            'params' => {
              'table' => table,
              'select' => 'all',
              'orgCode' => 3
            }
          }

          response = Faraday.new.post do |req|
            req.url File.join([@host] + url_path)
            req.headers['Content-Type'] = 'application/json'
            req.body = params.to_json
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("DataCycle::Generic::Gip -> error loading data from #{File.join([@host] + url_path)} / params:#{params}", response) unless response.success?
          JSON.parse(response.body.delete("\t").force_encoding('UTF-8')[4..-1]) # get rid of {}&&
        rescue StandardError
          raise if retry_count > @max_retry
          look_up(url_path, table, retry_count + 1)
        end

        def load_object_ids(url_path, params, retry_count = 0)
          response = Faraday.new.post do |req|
            req.url File.join([@host] + url_path)
            req.headers['Content-Type'] = 'application/json'
            req.body = params.to_json
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("DataCycle::Generic::Gip -> error loading data from #{File.join([@host] + url_path)} / params:#{params}", response) unless response.success?
          JSON.parse(response.body.delete("\t").force_encoding('UTF-8')[4..-1]) # get rid of {}&&
        rescue StandardError
          raise if retry_count > @max_retry
          load_object_ids(url_path, params, retry_count + 1)
        end

        def load_feature(url_path, object_id, retry_count = 0)
          response = Faraday.new.get do |req|
            req.url File.join([@host] + url_path)
            req.params['command'] = 'getfeature'
            req.params['objectid'] = object_id
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("DataCycle::Generic::Gip -> error loading data from #{File.join([@host] + url_path)} / params:#{params}", response) unless response.success?
          xml_data = Nokogiri::XML.parse(response.body)

          # puts Nokogiri::XML(response.body, &:noblanks).to_xml(indent: 2)

          xml_data.children.first.to_hash
        rescue StandardError
          raise if retry_count > @max_retry
          load_feature(url_path, object_id, retry_count + 1)
        end

        def load_data(url_path, params, retry_count = 0)
          response = Faraday.new.post do |req|
            req.url File.join([@host, @end_point] + url_path)
            req.options[:timeout] = 1000 # open/read timeout in seconds
            req.options[:open_timeout] = 1000
            req.headers['Content-Type'] = 'application/json'
            req.body = params.to_json
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("DataCycle::Generic::Gip -> error loading data from #{File.join([@host, @end_point] + url_path)} / params:#{params}", response) unless response.success?
          JSON.parse(response.body)
        rescue StandardError
          raise if retry_count > @max_retry
          load_data(url_path, params, retry_count + 1)
        end

        def load_routes
          raise ArgumentError, 'missing read_type for routes collection' if @read_type.nil?
          data = []
          DataCycleCore::Generic::Collection2.with(@read_type) do |mongo|
            aggregation_array = [
              { '$match':   { 'dump.de.featureMember.GeoName.refs': { '$exists': true } } },
              { '$unwind':  '$dump.de.featureMember.GeoName.refs.ReferenceItem' },
              { '$project': { 'id': '$dump.de.featureMember.GeoName.refs.ReferenceItem.fid' } },
              { '$group':   { '_id': '$id' } }
            ]
            data = mongo.collection.aggregate(aggregation_array).to_a
          end
          data.map { |i| i['_id'].split('_').last&.to_i }
        end
      end
    end
  end
end
