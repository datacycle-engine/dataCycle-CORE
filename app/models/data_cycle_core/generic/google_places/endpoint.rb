module DataCycleCore
  module Generic
    module GooglePlaces
      class Endpoint
        SCALE = 112_000.0 # ~ km/1° longitude

        def initialize(host: nil, end_point: nil, key: nil, bbox: nil, read_type: nil)
          @host = host
          @end_point = end_point
          @key = key
          @bbox = RGeo::Geographic.spherical_factory(srid: 4326).parse_wkt(bbox)
          @ul, @lr = @bbox.to_a
          @read_type = read_type
        end

        def places(lang: :de)
          scale = 100

          radius = SCALE / scale
          raster = 1.0 / scale

          lines, columns = calculate_grid(@bbox, radius)
          lat_start = @bbox.to_a.last.x + 3**0.5 / 2.0 * raster
          long_start = @bbox.to_a.first.y + 0.5 * raster

          Enumerator.new do |yielder|
            (0..lines).each do |x|
              x_pos = lat_start + x * 1.5 * raster
              y_start = x.odd? ? raster * 0.5 * 3**0.5 : 0
              (0..columns).each do |y|
                y_pos = long_start + y_start + y * raster * 3**0.5
                load_tile(x: x_pos, y: y_pos, r: radius). each do |record|
                  yielder << record
                end
              end
            end
          end
        end

        def places_detail
          Enumerator.new do |yielder|
            @read_type.find_each do |item|
              yielder << load_detail(item.external_id)['result']
            end
          end
        end

        # calculate hex-grid
        def calculate_grid(bbox, radius)
          a = radius * (3**0.5)
          scale = a / SCALE
          ul, lr = bbox.to_a
          lines = (ul.x - lr.x).abs / scale
          columns = (ul.y - lr.y).abs / scale
          return lines.ceil, columns.ceil
        end

        # zoom into one hex-grid-tile
        def zoom(x0, y0, a0)
          a_z = a0 * 3.0**0.5 / 4.0
          x_off = 3.0**0.5 / 2.0 * a_z
          y_off = 3.0 / 2.0 * a_z
          {
            'r' => a_z,
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

        def load_tile(x: 0, y: 0, r: 1150)
          data_pool = []
          next_page_token = nil
          page_no = 1
          loop do
            temp = load_data(location_x: x, location_y: y, radius: r, next_page: next_page_token)
            data_pool += temp['results']

            # got 60 datapoints within one query --> expect more to be present
            if page_no == 3 && temp['results'].size == 20
              new_tiles = zoom(x, y, r)
              new_tiles['tiles'].each do |tile|
                data_pool += load_tile(tile[0], tile[1], new_tiles['r'])
              end
            end
            next_page_token = temp['next_page_token']
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
          response = Faraday.new.get do |req|
            req.url(@host + @end_point + 'nearbysearch/json')
            req.headers['Accept'] = 'application/json'
            req.params['radius'] = radius
            req.params['location'] = [location_x, location_y].join(',')
            req.params['key'] = @key
            req.params['language'] = 'de'
            req.params['pagetoken'] = next_page
          end
          if response.success?
            JSON.parse(response.body)
          else
            raise DataCycleCore::Generic::RecoverableError, "error loading data from #{@host + @end_point} / page:#{page} / per:#{per} / lang:#{lang} / type:#{type}" << response.body
          end
        end

        def load_detail(place_id)
          response = Faraday.new.get do |req|
            req.url(@host + @end_point + 'detail/json')
            req.headers['Accept'] = 'application/json'
            req.params['key'] = @key
            req.params['language'] = 'de'
            req.params['placeid'] = place_id
          end
          if response.success?
            JSON.parse(response.body)
          else
            raise DataCycleCore::Generic::RecoverableError, "error loading data from #{@host + @end_point} / page:#{page} / per:#{per} / lang:#{lang} / type:#{type}" << response.body
          end
        end
      end
    end
  end
end
