module DataCycleCore
  class StatsDatabase

    attr_accessor :stat_update, :pg_name,
                  :pg_classifications, :pg_places, :pg_classification_places, :pg_size,
                  :pg_creative_works, :pg_creative_work_places, :pg_creative_work_classification, :pg_overlays,
                  :mongo_categories, :mongo_pois, :mongo_regions,
                  :import_modules

    def initialize( user_id )
        @import_modules = []
        load_postgres_data
        load_mongo_data( user_id )
    end

    def update( user_id )
      load_postgres_data
      load_mongo_data( user_id )
      return self
    end

    private

    def load_postgres_data
      @stat_update = Time.zone.now

      @pg_name = ActiveRecord::Base.connection.current_database
      sql = "SELECT pg_database_size('#{@pg_name}');"

      @pg_size = ActiveRecord::Base.connection.execute(sql).first['pg_database_size']
      @pg_classifications = Classification.count
      @pg_places = Place.count
      @pg_classification_places = ClassificationPlace.count
      @pg_creative_works = CreativeWork.count
      @pg_creative_work_places = CreativeWorkPlace.count
      @pg_creative_work_classification = ClassificationCreativeWork.count
      @pg_overlays = Overlay.count
    end


    def load_mongo_data ( user_id )
      mongo_dbs = OutdoorActive::DownloadPoi.mongo_client.list_databases

      UseCase.where(user_id: user_id).each do |use_case|
        external_source_id = use_case.external_source_id
        external_source = ExternalSource.where(id: external_source_id).first
        import_name = external_source.name

        Mongoid.override_database(nil)
        mongo_database = "#{OutdoorActive::DownloadPoi.database_name}_#{external_source_id}"
        Mongoid.override_database(mongo_database)
        mongo_dbs_index = mongo_dbs.find_index { |db| db["name"]==mongo_database }

        if mongo_dbs_index.nil?
          @import_modules.push({
              uuid: external_source_id,
              name: import_name,
              database: mongo_database,
              db_size: 0,
              tables: {
                pois: 0,
                categories: 0,
                regions: 0
              },
              last_import: "never",
              last_download: "never"
          })
        else
          mongo_dbsize = mongo_dbs[mongo_dbs_index]['sizeOnDisk']
          mongo_categories = OutdoorActive::DownloadCategory.count
          mongo_pois = OutdoorActive::DownloadPoi.count
          mongo_regions = OutdoorActive::DownloadRegion.count
          mongo_creative_works = Jsonld::DownloadCreativeWork.count

          if external_source.last_import.nil?
            last_import = "never"
          else
            last_import = external_source.last_import.to_s + "<i class='material-icons green'>done</i>"
          end

          if external_source.last_download.nil?
            last_download = "never"
          else
            last_download = external_source.last_download.to_s + "<i class='material-icons green'>done</i>"
          end

          @import_modules.push({
              uuid: external_source_id,
              name: import_name,
              database: mongo_database,
              db_size: mongo_dbsize,
              tables: {
                pois: mongo_pois,
                categories: mongo_categories,
                regions: mongo_regions,
                creative_work: mongo_creative_works
              },
              last_import: last_import,
              last_download: last_download
          })
        end
      end
    end

  end
end
