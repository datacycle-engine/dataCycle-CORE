module DataCycleCore
  module Jsonld

    class Download

      def initialize(uuid, incremental_update = false, page_size = 300, verbose = false )
        @uuid = uuid
        @download_page_size = page_size
        @verbose = verbose
        @log = DataCycleCore::Logger.new("jsonld_download")
        external_source = ExternalSource.where(id: uuid).first
        credentials = external_source.credentials
        @connRestClient = RestClient.new("http://localhost:3000", credentials, verbose)
      end

      def download
        Mongoid.override_database(nil) #reset to default
        Mongoid.override_database("#{DownloadCreativeWork.database_name}_#{@uuid}")

        download_logging do
          download_creative_works
        end

        Mongoid.override_database(nil) #reset to default
      end

    private

      def download_creative_works
        response = @connRestClient.get('/api/v1/media.json',1,1)
        @log.error "  could not load JSON-LD end-point, HTTP-Response = #{response.status}" unless response.status == 200
        initial_download = JSON.parse(response.body)
        total_items = initial_download['count'].to_i
        pages = total_items.fdiv(@download_page_size).ceil

        print "downloading: "
        (pages-1).times do |i|
          print "."
          response = @connRestClient.get('/api/v1/media.json', i+1, @download_page_size)
          @log.error "  could not load JSON-LD end-point, HTTP-Response = #{response.status}" unless response.status == 200
          data = JSON.parse(response.body)['CreativeWorks']

          data.each do |data_set|
            old_creative_work = DownloadCreativeWork.find(id: data_set["@id"])
            if old_creative_work.nil?
              creative_work = DownloadCreativeWork.new
              creative_work.id = data_set["@id"]
              creative_work.created_at = Time.zone.now
            else
              creative_work = old_creative_work
            end
            creative_work.dump = data_set
            creative_work.updated_at = Time.zone.now
            creative_work.seen_at = Time.zone.now
            creative_work.save
          end
        end
        puts "\n"
      end


      def download_logging
        start_timestamp = Time.zone.now
        @log.info "BEGIN DOWNLOAD : " + start_timestamp.to_s
        @log.info 'JSON-LD Download:'
        @log.info "MongoDb: #{DownloadCreativeWork.database_name}"

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

    end

  end
end
