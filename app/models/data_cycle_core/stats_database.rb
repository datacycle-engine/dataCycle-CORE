# frozen_string_literal: true

module DataCycleCore
  class StatsDatabase
    attr_accessor(
      :stat_update, :pg_name, :pg_size, :pg_content, :pg_content_content,
      :pg_classification_content, :pg_classifications, :pg_aliases, :pg_overlays,
      :pg_content_history, :pg_tree_label, :pg_tree_nodes, :mongo_categories,
      :mongo_pois, :mongo_regions, :import_modules
    )

    def initialize(user_id)
      @import_modules = []
      load_postgres_data
      load_mongo_data(user_id)
    end

    def update(user_id)
      load_postgres_data
      load_mongo_data(user_id)
      self
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
      @pg_content['Thing'] = DataCycleCore::Thing.count
      @pg_content['Thing-Translations'] = DataCycleCore::Thing::Translation.count
      @pg_content['History'] = DataCycleCore::Thing::History.count
      @pg_content['History-Translations'] = DataCycleCore::Thing::History::Translation.count

      @pg_content_content = DataCycleCore::ContentContent.count
    end

    def load_mongo_data(_user_id)
      mongo_dbs = Generic::Collection.mongo_client.list_databases

      DataCycleCore::ExternalSource.find_each do |external_source|
        import_name = external_source.name
        next if external_source.config.blank?

        Mongoid.override_database(nil)
        mongo_database = "#{Generic::Collection.database_name}_#{external_source.id}"
        Mongoid.override_database(mongo_database)
        mongo_dbs_index = mongo_dbs.find_index { |db| db['name'] == mongo_database }

        if mongo_dbs_index.nil?
          @import_modules.push(
            {
              uuid: external_source.id,
              name: import_name,
              database: mongo_database,
              db_size: 0,
              tables: {
                "no collections found": 0
              },
              last_import: 'never',
              last_download: 'never'
            }
          )
        else
          mongo_dbsize = mongo_dbs[mongo_dbs_index]['sizeOnDisk']
          Mongoid.clients[external_source.id] = {
            'database' => mongo_database,
            'hosts' => Mongoid.default_client.cluster.servers.map(&:address).map { |adr| "#{adr.host}:#{adr.port}" },
            'options' => nil
          }
          mongo_data = Hash[Mongoid.client(external_source.id).collections.map { |item| [item.name.humanize, item.count] }]

          if external_source.last_import.nil?
            last_import = 'never'
          else
            last_import = external_source.last_import.to_s
          end

          if external_source.last_download.nil?
            last_download = 'never'
          else
            last_download = external_source.last_download.to_s
          end

          @import_modules.push(
            {
              uuid: external_source.id,
              name: import_name,
              database: mongo_database,
              db_size: mongo_dbsize,
              tables: mongo_data,
              last_import: last_import,
              last_download: last_download
            }
          )
        end
      end
      Mongoid.override_database(nil)
    end
  end
end
