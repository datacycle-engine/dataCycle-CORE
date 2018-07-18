# frozen_string_literal: true

module DataCycleCore
  module Generic
    module GooglePlaces
      class Endpoint
        SCALE = 112_000.0 # ~ km/1° longitude
        FIXNUM_MAX = (2**(0.size * 4 - 2) - 1)

        attr_reader :border, :bbox, :factory
        def initialize(host: nil, end_point: nil, key: nil, bbox: nil, **options)
          @host = host
          @end_point = end_point
          @key = key
          @read_type = options[:read_type] if options[:read_type].present?

          @factory = RGeo::Geographic.simple_mercator_factory
          @border = RGeo::GeoJSON.decode(File.read(Rails.root.join(options[:geojson])), geo_factory: @factory).first.geometry.first
          @bbox = RGeo::Cartesian::BoundingBox.create_from_geometry(@border)

          # if options[:geojson].present?
          #   @border = RGeo::GeoJSON.decode(File.read(Rails.root.join(options[:geojson])), geo_factory: @factory).first.geometry.first
          #   @bbox = RGeo::Cartesian::BoundingBox.create_from_geometry(@border)
          # else
          #   @border = nil
          #   points = @factory.parse_wkt(bbox)
          #   @bbox = RGeo::Cartesian::BoundingBox.create_from_points(points.to_a.first, points.to_a.last)
          # end
        end

        def places(lang: :de)
          raster_scale = 50

          radius = SCALE / raster_scale
          raster = 1.0 / raster_scale

          lines, columns = calculate_grid(bbox, raster)
          lat_start = bbox.min_y + 0.5 * raster
          long_start = bbox.min_x

          Enumerator.new do |yielder|
            (0..lines).each do |y|
              y_pos = lat_start + y.to_f * 1.5 * raster
              x_start = y.odd? ? raster * 0.5 * 3**0.5 : 0.0
              (0..columns).each do |x|
                x_pos = long_start + x_start + x.to_f * raster * 3**0.5
                position = factory.parse_wkt("POINT (#{x_pos} #{y_pos})")
                # puts "skipped   (x: #{x_pos.round(6).to_s.rjust(10)}, y: #{y_pos.round(6).to_s.rjust(10)}, r: #{radius})" if @border.present? && position.buffer(radius).distance(@border).positive?
                next if border.present? && position.buffer(radius).distance(border).positive?
                # puts "load_tile (x: #{x_pos.round(6).to_s.rjust(10)}, y: #{y_pos.round(6).to_s.rjust(10)}, r: #{radius})"
                load_tile(x: x_pos, y: y_pos, r: radius, i: raster).each do |record|
                  lat = record.dig('geometry', 'location', 'lat')
                  lng = record.dig('geometry', 'location', 'lng')
                  position = nil
                  position = factory.parse_wkt("POINT (#{lng} #{lat})") if lat.present? && lng.present?
                  # puts "pos: (#{record.dig('geometry', 'location', 'lng')}/#{record.dig('geometry', 'location', 'lat')})"
                  # puts "name: #{record.dig('name')}"
                  # puts "land: #{record.dig('address_component')&.select { |item| item['types'].include?('country') }&.first&.dig('long_name')}"
                  # puts "skip: #{@border.present? && position.present? && position.distance(@border).positive?}"
                  next if border.present? && position.present? && position.distance(border).positive?
                  yielder << record
                end
              end
            end
          end
        end

        def places_detail(lang: :de)
          Enumerator.new do |yielder|
            DataCycleCore::Generic::Collection2.with(@read_type) do |mongo_item|
              mongo_item.no_timeout.max_time_ms(FIXNUM_MAX).each do |item|
                yielder << load_detail(item.external_id)['result']
              end
            end
          end
        end

        # calculate hex-grid
        def calculate_grid(bbox, raster)
          scale_y = raster * 1.5
          scale_x = raster * 3**0.5
          columns = (bbox.max_x - bbox.min_x) / scale_x
          lines = (bbox.max_y - bbox.min_y) / scale_y
          return lines.ceil, columns.ceil
        end

        # zoom into one hex-grid-tile
        def zoom(x0, y0, a0, i)
          a_z = a0 * 3.0**0.5 / 4.0
          incr = i * a_z / a0
          x_off = 3.0**0.5 / 2.0 * incr
          y_off = 3.0 / 2.0 * incr
          {
            'r' => a_z,
            'i' => incr,
            'tiles' => [
              [x0, y0],
              [x0 + 2 * x_off, y0],
              [x0 - 2 * x_off, y0],
              [x0 + x_off, y0 + y_off],
              [x0 - x_off, y0 + y_off],
              [x0 + x_off, y0 - y_off],
              [x0 - x_off, y0 - y_off]
            ]
          }
        end

        protected

        def load_tile(x: 0, y: 0, r: 1150, i: 0.01)
          data_pool = []
          next_page_token = nil
          page_no = 1
          loop do
            temp = load_data(location_x: x, location_y: y, radius: r, next_page: next_page_token)
            data_pool += temp['results']
            # puts "loaded    (#{x}, #{y}, #{r}, #{next_page_token.present?}) /// items: #{temp['results'].size}/// paging: #{page_no}"
            # got 60 datapoints within one query --> expect more to be present ==> zoom
            if r > 50
              if page_no == 3 && temp['results'].size == 20
                new_tiles = zoom(x, y, r, i)
                # puts "***ZOOM***(#{x}, #{y}, #{r}, #{i})"
                new_tiles['tiles'].each do |tile|
                  # puts "load_zoom (#{tile[0]}, #{tile[1]}, #{new_tiles['r']}, #{new_tiles['i']})"
                  position = factory.parse_wkt("POINT (#{tile[0]} #{tile[1]})")
                  data_pool += load_tile(x: tile[0], y: tile[1], r: new_tiles['r'], i: new_tiles['i']) if border.present? && position.buffer(new_tiles['r']).distance(border).zero?
                end
              end
              next_page_token = temp['next_page_token']
            else
              temp.delete('next_page_token')
            end
            if temp.key?('next_page_token')
              page_no += 1
            else
              page_no = 1
              break
            end
          end

          data_pool
        end

        def load_data(location_x: 0, location_y: 0, radius: 1000, next_page: nil)
          # puts "--> load: (#{next_page})" if next_page.present?
          # puts "--> load: (#{[location_x.round(6), location_y.round(6)].join(',')}) // #{radius.round(6)}"
          attempts = 1
          if next_page.nil?
            response = Faraday.new.get do |req|
              req.url(@host + @end_point + 'nearbysearch/json')
              req.headers['Accept'] = 'application/json'
              req.params['radius'] = radius
              req.params['location'] = [location_y, location_x].join(',')
              req.params['key'] = @key
              req.params['language'] = 'de'
            end
          else
            attempts = 1
            loop do
              sleep 1 # TODO: test how low it can reliably get
              response = Faraday.new.get do |req|
                req.url(@host + @end_point + 'nearbysearch/json')
                req.headers['Accept'] = 'application/json'
                req.params['key'] = @key
                req.params['pagetoken'] = next_page
                req.params['language'] = 'de'
              end
              data = JSON.parse(response.body)
              # items = data['results'].size
              # puts "====> #{items} <===="
              # puts data['status']
              break if data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS' || attempts > 180
              attempts += 1
            end
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point + 'nearbysearch/json'} / x:#{location_x} / y:#{location_y} / r:#{radius}", response) unless response.success?
          data = JSON.parse(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{data['status']},(#{attempts}) error loading data from #{@host + @end_point + 'nearbysearch/json'} / x:#{location_x} / y:#{location_y} / r:#{radius}", response) unless data['status'] == 'OK' || data['status'] == 'ZERO_RESULTS'
          data
        end

        def load_detail(place_id)
          response = Faraday.new.get do |req|
            req.url(@host + @end_point + 'details/json')
            req.headers['Accept'] = 'application/json'
            req.params['key'] = @key
            req.params['language'] = 'de'
            req.params['placeid'] = place_id
          end
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("error loading data from #{@host + @end_point + 'details/json'} / place_id: #{place_id}", response) unless response.success?
          data = JSON.parse(response.body)
          raise DataCycleCore::Generic::Common::Error::EndpointError.new("#{data['status']}, error loading data from #{@host + @end_point + 'details/json'} / place_id: #{place_id}", response) unless data['status'] == 'OK'
          data
        end
      end
    end
  end
end
