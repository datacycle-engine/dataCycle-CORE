module DataCycleCore
  module OutdoorActive

    class Download

      def initialize ( uuid, incremental_update = false, page_size = 300, max_item_count = nil, verbose = false )
        @uuid = uuid
        @download_page_size = page_size
        @max_item_count = max_item_count
        @verbose = verbose
        @log = DataCycleCore::Logger.new("outdooractive_download")
        external_source = ExternalSource.where(id: uuid).first
        credentials = external_source.credentials
        @connRestClient = RestClient.new('http://www.outdooractive.com/', credentials, verbose)
      end

      def download(options = {})
        Mongoid.override_database(nil) #reset to default
        Mongoid.override_database("#{DownloadPoi.database_name}_#{@uuid}")

        download_logging do
          download_category
          download_region
          download_pois('pois')
          download_pois('tours')
        end

        Mongoid.override_database(nil) #reset to default
      end


    private

    # Category
      def download_category
        download_category_logging do
          response = @connRestClient.get_category_tree
          @log.error "  could not load CategoryTree, HTTP-Response = #{response.status}" unless response.status == 200

          category_tree = JSON.parse(response.body)['category']
          parse_category(category_tree)
        end
      end

      def parse_category(category)
        category.each do |sub_category|
          indexes_processed = parse_subcategory(sub_category, nil)
        end
      end

      def parse_subcategory(category, parent_id)
        save_category(category, parent_id)
        new_parent_id = category['id']
        unless category['category'].nil?
          category['category'].each do |sub_category|
            parse_subcategory(sub_category, new_parent_id)
          end
        end
      end

      def save_category(category_hash, parent_id)
        processed_category = DownloadCategory.find({id: category_hash['id']})
        if processed_category.nil?
          processed_category = DownloadCategory.new
          processed_category.id = category_hash['id']
          processed_category.parent_id = parent_id unless parent_id.nil?
          processed_category.created_at = Time.zone.now
        end
        processed_category.name = category_hash['name']
        processed_category.dump = category_hash
        processed_category.updated_at = Time.zone.now
        processed_category.seen_at = Time.zone.now
        processed_category.upsert
      end


    # Region
      def download_region
        download_region_logging do
          response = @connRestClient.get_region_tree
          @log.error "  could not load RegionTree, HTTP-Response = #{response.status}" unless response.status == 200

          region_tree = JSON.parse(response.body)['region'][0]
          parse_regions_tree(region_tree, nil)
        end
      end

      def parse_regions_tree(regions, parent_id)
        save_region(regions, parent_id)
        new_parent_id = regions['id']
        unless regions['region'].nil?
          regions['region'].each do |sub_region|
            parse_regions_tree(sub_region, new_parent_id)
          end
        end
      end

      def save_region (regions, parent_id)
        unless parent_id == regions['id']  # inconsistent data
          processed_region = DownloadRegion.find({id: "#{parent_id}/#{regions['id']}"})
          if processed_region.nil?
            processed_region = DownloadRegion.new
            processed_region.id = "#{parent_id}/#{regions['id']}"
            processed_region.region_id = regions['id']
            processed_region.parent_id = parent_id
            processed_region.created_at = Time.zone.now
          end
          processed_region.name = regions['name']
          processed_region.level = regions['level'].to_i
          processed_region.regionType = regions['type']
          processed_region.categoryId = regions['categoryId'].to_i
          processed_region.categoryTitle = regions['categoryTitle']
          processed_region.hasTour = regions['hasTour']
          processed_region.bbox = regions['bbox']
          processed_region.updated_at = Time.zone.now
          processed_region.seen_at = Time.zone.now
          processed_region.upsert
        end
      end


    #POI/Tours
      def download_pois(end_point)
        download_poi_data_logging(end_point) do
          response = @connRestClient.get_poi_tour_index(end_point)
          @log.error "  could not load Indexes for #{end_point}, HTTP-Response = #{response.status}" unless response.status == 200

          if @incremental_update
            @log.info "  -- check for inserts/updates"
            determine_poi_upserts(response.body, end_point)
            indexes = DownloadPoiUpsert.all.sort.map { |x| x.id }
          else
            indexes = JSON.parse(response.body)['data'].collect { |selected_poi| selected_poi['id']}
          end
          
          if @max_item_count
            download_poi_details(end_point, indexes[0..(@max_item_count - 1)])
          else
            download_poi_details(end_point, indexes)
          end
        end
      end

      def determine_poi_upserts(pois, end_point)
        new_pois = 0
        updated_pois = 0
        @log.info "  -- download indexes for #{end_point}"
        @log.info "  -- pending upserts before download: #{DownloadPoiUpsert.count}"

        JSON.parse(pois)['data'].each do |selected_poi|
          old_poi = DownloadPoi.find({id: selected_poi['id']})
          if old_poi.nil?
            new_pois += 1
            insert_poi = DownloadPoiUpsert.new
            insert_poi.id = selected_poi['id']
            insert_poi.insert
          else
            old_poi.seen_at = Time.zone.now
            old_poi.update
            updated_pois += 1 if old_poi.lastModified < selected_poi['lastModified']
          end
        end
        @log.info "  -- found -- #{new_pois} new and #{updated_pois} updated #{end_point}"
      end

      def download_poi_details(end_point, indexes)
        indexes_lang = {}
        @log.info "  -- determining translations"
        print " " * 40 + "loading"
        indexes_size = indexes.size
        indexes_size_debug = indexes.size
        if indexes_size > 0
          (0..indexes_size_debug).step(@download_page_size).to_a.each do |start_index|
            print '.'

            request_indexes = indexes[start_index..(start_index+@download_page_size-1)].join(',')
            response = @connRestClient.get_poi_tour_details(request_indexes, nil)
            @log.error "  could not load #{end_point}-details, HTTP-Response = #{response.status}" unless response.status == 200
            downloaded_data = JSON.parse(response.body)

            unless downloaded_data['poi'].nil?
              downloaded_data['poi'].each do |point|
                point['meta']['translation'].each do |lang|
                  if indexes_lang.has_key?(lang.to_sym)
                    indexes_lang[lang.to_sym].push(point['id'])
                  else
                    indexes_lang.merge!({lang.to_sym => [point['id']]})
                  end
                end
              end
            end

            unless downloaded_data['tour'].nil?
              downloaded_data['tour'].each do |tour|
                tour['meta']['translation'].each do |lang|
                  if indexes_lang.has_key?(lang.to_sym)
                    indexes_lang[lang.to_sym].push(tour['id'])
                  else
                    indexes_lang.merge!({lang.to_sym => [tour['id']]})
                  end
                end
              end
            end
          end
        end
        puts "\n"
        @log.info "  -- translations determined: "
        indexes_lang.each do |lang, index_lang|
          @log.info "          #{lang}: #{index_lang.count}"
          download_poi_details_lang(end_point, index_lang, lang)
        end
        @log.info "       uniqe: #{indexes.count} #{end_point}"
        @log.info "  -- processed: #{DownloadPoi.count}"
      end

      def download_poi_details_lang(end_point, indexes, lang)
        print " " * 51 + "loading"
        if indexes.size > 0
          (0..indexes.size-1).step(@download_page_size).to_a.each do |start_index|
            print '.'
            request_indexes = indexes[start_index..(start_index+@download_page_size-1)].join(',')
            response = @connRestClient.get_poi_tour_details(request_indexes, lang.to_s)
            @log.error "  could not load #{end_point}-details, HTTP-Response = #{response.status}" unless response.status == 200
            downloaded_data = JSON.parse(response.body)

            unless downloaded_data['poi'].nil?
              downloaded_data['poi'].each do |point|
                save_poi_details(point, lang)
              end
            end

            unless downloaded_data['tour'].nil?
              downloaded_data['tour'].each do |tour|
                save_poi_details(tour, lang)
              end
            end
          end
        end
        puts "\n"
      end

      def save_poi_details(poi_data, lang)
        processed_poi = DownloadPoi.find({id: poi_data['id']})
        if processed_poi.nil?
          processed_poi = DownloadPoi.new
          processed_poi.id = poi_data['id']
          processed_poi.created_at = Time.zone.now
        end
        processed_poi.updated_at = Time.zone.now
        processed_poi.seen_at = Time.zone.now
        processed_poi.title = poi_data['title']
        processed_poi.lastModified = DateTime.parse(poi_data['meta']['date']['lastModified'])
        processed_poi.dump = {} if processed_poi.dump.nil?
        processed_poi.dump[lang] = poi_data
        processed_poi.upsert
      end


    # logging ceremony for the download logic
      def download_logging
        start_timestamp = Time.zone.now
        @log.info "BEGIN DOWNLOAD : " + start_timestamp.to_s
        @log.info 'OutdoorActive Download:'
        @log.info "MongoDb: #{DownloadPoi.database_name}"

        save_logger_level = Rails.logger.level
        Rails.logger.level = 4 unless @verbose

        # to force mongoid to return nil if nothing is found
        Mongoid.raise_not_found_error = false

        yield

        end_timestamp = Time.zone.now
        @log.info "  total time download/update: #{(end_timestamp-start_timestamp).round(2)} [s]"
        @log.info 'end'
        @log.info "END DOWNLOAD : " + end_timestamp.to_s

        Rails.logger.level = save_logger_level
      end


      def download_category_logging
        @log.info "  download: categories"
        @log.info "  -- Categories before Update:    #{DownloadCategory.count}"
        start_time = Time.zone.now

        yield

        end_time = Time.zone.now
        @log.info "  -- download/update time:            #{(end_time-start_time).round(2)} [s]"
        @log.info "  -- Categories after  Update:    #{DownloadCategory.count}"
      end


      def download_region_logging
        @log.info "  download: regions"
        @log.info "  -- Regions before Update:       #{DownloadRegion.count}"
        start_time = Time.zone.now

        yield

        end_time = Time.zone.now
        @log.info "  -- download/update time:            #{(end_time-start_time).round(2)} [s]"
        @log.info "  -- Regions after  Update:       #{DownloadRegion.count}"

      end

      def download_poi_data_logging(end_point)
        @log.info "  download: #{end_point}"
        start_time = Time.zone.now

        yield

        end_time = Time.zone.now
        @log.info "  -- download/update time: #{(end_time-start_time).round(2)} [s]"
      end

    end

  end
end
