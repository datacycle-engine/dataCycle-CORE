# frozen_string_literal: true

module DataCycleCore
  module Generic
    module FeratelWebcam
      class Endpoint
        def initialize(host: nil, pg: nil, d: nil, cam_host: nil, cams: [], **options)
          @host = host
          @pg = pg
          @d = d
          @cam_data = cams
          @cams = cams.map { |i| i.dig('id') }
          @cam_host = cam_host
          @read_type = options[:read_type] if options[:read_type].present?
        end

        def load_cam_ids
          raise ArgumentError, 'missing read_type for loading cam_ids' if @read_type.nil?
          DataCycleCore::Generic::Collection2.with(@read_type) do |mongo|
            mongo.where({ 'dump.de.rid' => { '$exists' => true } }).map { |r| r.dump['de']['rid'] }
          end
        end

        def root_cams(lang: :de)
          Enumerator.new do |yielder|
            @cam_data.each do |cam|
              yielder << { 'rid' => cam.dig('id'), 'name' => cam.dig('name') }
            end

            @cams.each do |cam_id|
              # pc = 6 // weitere cams
              load_data(cam: cam_id, pc: 6, lang: lang).dig('co', 'pl', 'pcs', 'pc').detect { |i| i['t'] == '6' }&.dig('fcs', 'fci')&.each do |cam_list_data|
                rid = cam_list_data['rid']
                name =
                  cam_list_data.dig('fcid').detect { |i| i['t'] == '1' }&.dig('v') ||
                  cam_list_data.dig('fcid').detect { |i| i['t'] == '2' }&.dig('v') ||
                  cam_list_data.dig('fcid').detect { |i| i['t'] == '3' }&.dig('v') ||
                  cam_list_data.dig('fcid').detect { |i| i['t'] == '4' }&.dig('v')
                yielder << { 'rid' => rid, 'name' => name }
              end
            end
          end
        end

        def cam_details(lang: :de)
          Enumerator.new do |yielder|
            load_cam_ids.each do |cam_id|
              yielder << load_data(cam: cam_id, pc: 1, lang: lang).merge({ 'config' => { 'cam_host' => @cam_host, 'pg' => @pg } })
            end
          end
        end

        def weather_details(lang: :de)
          Enumerator.new do |yielder|
            load_cam_ids.each do |cam_id|
              yielder << load_data(cam: cam_id, pc: 3, lang: lang)
            end
          end
        end

        def lift_details(lang: :de)
          Enumerator.new do |yielder|
            load_cam_ids.each do |cam_id|
              yielder << load_data(cam: cam_id, pc: 4, lang: lang, pccd: 0)
            end
          end
        end

        def slope_details(lang: :de)
          Enumerator.new do |yielder|
            load_cam_ids.each do |cam_id|
              yielder << load_data(cam: cam_id, pc: 4, lang: lang, pccd: 1)
            end
          end
        end

        def infrastructure_details(lang: :de)
          Enumerator.new do |yielder|
            load_cam_ids.each do |cam_id|
              yielder << load_data(cam: cam_id, pc: 4, lang: lang, pccd: 2)
            end
          end
        end

        def slope_legends(lang: :de)
          Enumerator.new do |yielder|
            raw_data = load_data(cam: load_cam_ids.first, pc: 4, lang: lang, pccd: 4)
            raw_data
              .dig('co', 'pl', 'pcs', 'pc').detect { |i| i['t'] == '4' }
              &.dig('pcc', 'pccd')&.detect { |i| i['t'] == '4' }
              &.dig('csi', 'ci')&.each do |classifications|
              yielder << classifications
            end
          end
        end

        protected

        def load_data(cam:, pc:, lang:, pccd: nil)
          connection = Faraday.new(@host) do |con|
            con.use FaradayMiddleware::FollowRedirects, limit: 5
            con.adapter Faraday.default_adapter
          end
          response = connection.get do |req|
            req.params['pg'] = @pg
            req.params['lg'] = lang.to_s
            req.params['d'] = @d
            req.params['pc'] = pc
            req.params['cam'] = cam
            req.params['pccd'] = pccd if pccd.present?
          end

          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host}", response) unless response.success?
          Nokogiri::XML(response.body).children.first.to_hash
        end
      end
    end
  end
end
