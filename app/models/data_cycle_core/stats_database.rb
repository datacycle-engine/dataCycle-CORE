module DataCycleCore
  class StatsDatabase
    attr_accessor :stat_update, :pg_name, :pg_size,
                  :pg_content, :pg_content_content, :pg_classification_content,
                  :pg_classifications, :pg_aliases, :pg_overlays, :pg_content_history,
                  :pg_tree_label, :pg_tree_nodes,
                  :mongo_categories, :mongo_pois, :mongo_regions,
                  :import_modules

    def initialize(user_id)
      @import_modules = []
      load_postgres_data
      load_mongo_data(user_id)
    end

    def update(user_id)
      load_postgres_data
      load_mongo_data(user_id)
      return self
    end

    private

    def load_postgres_data
      @stat_update = Time.zone.now

      @pg_name = ActiveRecord::Base.connection.current_database
      sql = ActiveRecord::Base.send(:sanitize_sql_for_conditions, "SELECT pg_database_size('#{@pg_name}');")

      @pg_size = ActiveRecord::Base.connection.execute(sql).first['pg_database_size']
      @pg_classifications = Classification.count
      @pg_aliases = ClassificationAlias.count
      @pg_classification_content = ClassificationContent.count
      @pg_tree_label = ClassificationTreeLabel.count
      @pg_tree_nodes = ClassificationTree.count

      @pg_content = {}
      @pg_content_history = 0
      DataCycleCore.content_tables.each do |item|
        @pg_content[item.humanize] = ("DataCycleCore::" + item.classify).safe_constantize.count
        @pg_content_history += "DataCycleCore::#{item.classify}::History".safe_constantize.count
      end

      @pg_content_content = DataCycleCore::ContentContent.count
      @pg_overlays = Overlay.count
    end

    def load_mongo_data(user_id)
      mongo_dbs = Generic::Collection.mongo_client.list_databases

      UseCase.where(user_id: user_id).each do |use_case|
        external_source_id = use_case.external_source_id
        external_source = ExternalSource.where(id: external_source_id).first
        import_name = external_source.name

        Mongoid.override_database(nil)
        mongo_database = "#{Generic::Collection.database_name}_#{external_source_id}"
        Mongoid.override_database(mongo_database)
        mongo_dbs_index = mongo_dbs.find_index { |db| db["name"] == mongo_database }

        if mongo_dbs_index.nil?
          @import_modules.push({
                                 uuid: external_source_id,
                                 name: import_name,
                                 database: mongo_database,
                                 db_size: 0,
                                 tables: {
                                   "no collections found": 0
                                 },
                                 last_import: "never",
                                 last_download: "never"
                               })
        else
          mongo_dbsize = mongo_dbs[mongo_dbs_index]['sizeOnDisk']
          Mongoid.clients[external_source_id] = {
            "database" => mongo_database,
            "hosts" => Mongoid.default_client.cluster.servers.map(&:address).map { |adr| "#{adr.host}:#{adr.port}" },
            "options" => nil
          }
          mongo_data = Hash[Mongoid.client(external_source_id).collections.map { |item| [item.name.humanize, item.count] }]

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
                                 tables: mongo_data,
                                 last_import: last_import,
                                 last_download: last_download
                               })
        end
      end
    end
  end
end
